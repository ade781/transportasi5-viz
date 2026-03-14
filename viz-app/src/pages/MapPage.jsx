import { useState, useEffect, useMemo, useCallback, useRef } from 'react'
import Map, {
    Source, Layer, Popup,
    NavigationControl, ScaleControl, FullscreenControl
} from 'react-map-gl/maplibre'
import 'maplibre-gl/dist/maplibre-gl.css'
import {
    loadCSV,
    CLUSTER_COLORS,
    CLUSTER_LABELS,
    normalizeCorridorField,
    normalizeCorridor,
    filterRulesByMaxSupportConfidence
} from '../utils'

/* ── corridor colors for A/B display ── */
const CORRIDOR_A_COLOR = '#e74c3c'
const CORRIDOR_B_COLOR = '#3498db'
const SHARED_COLOR = '#9b59b6'

/* ── free vector tile styles from OpenFreeMap (no API key required) ── */
const MAP_STYLES = {
    liberty: 'https://tiles.openfreemap.org/styles/liberty',
    positron: 'https://tiles.openfreemap.org/styles/positron',
    bright: 'https://tiles.openfreemap.org/styles/bright',
}

/* ── MapLibre layer definitions — module-level so they are not recreated on each render ── */
// Use plain coalesce (to-number with fallback arg is Mapbox-only, not MapLibre)
const _SR = ['coalesce', ['get', 'radius'], 6]

const CIRCLE_LAYER = {
    id: 'halte-circles', type: 'circle',
    paint: {
        'circle-color': ['get', 'markerColor'],
        'circle-radius': ['interpolate', ['linear'], ['zoom'],
            9, ['/', _SR, 2], 13, _SR, 16, ['*', _SR, 1.5]
        ],
        // inRuleMode=1 → full opacity + thick stroke; isSelected → even thicker
        'circle-opacity': ['case', ['==', ['get', 'inRuleMode'], 1], 1.0, 0.88],
        'circle-stroke-width': ['case',
            ['==', ['get', 'isSelected'], 1], 3.5,
            ['==', ['get', 'inRuleMode'], 1], 2.5,
            1
        ],
        'circle-stroke-color': ['case',
            ['==', ['get', 'isSelected'], 1], '#fff',
            ['==', ['get', 'inRuleMode'], 1], 'rgba(255,255,255,0.9)',
            'rgba(255,255,255,0.5)'
        ],
    }
}
const HEATMAP_LAYER = {
    id: 'halte-heat', type: 'heatmap',
    paint: {
        'heatmap-weight': ['interpolate', ['linear'], ['coalesce', ['get', 'total_penumpang_bulan'], 0], 0, 0, 600000, 1],
        'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 9, 0.8, 14, 1.5],
        'heatmap-color': ['interpolate', ['linear'], ['heatmap-density'],
            0, 'rgba(33,102,172,0)', 0.2, 'rgb(103,169,207)', 0.4, 'rgb(209,229,240)',
            0.6, 'rgb(253,219,199)', 0.8, 'rgb(239,138,98)', 1, 'rgb(178,24,43)'
        ],
        'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 9, 14, 14, 22],
        'heatmap-opacity': ['interpolate', ['linear'], ['zoom'], 12, 0.85, 16, 0.3],
    }
}
const CLUSTER_CIRCLE_LAYER = {
    id: 'clusters', type: 'circle', filter: ['has', 'point_count'],
    paint: {
        'circle-color': ['step', ['get', 'point_count'], '#51bbd6', 50, '#f1a90b', 200, '#f28cb1'],
        'circle-radius': ['step', ['get', 'point_count'], 18, 50, 26, 200, 34],
        'circle-opacity': 0.85, 'circle-stroke-width': 2, 'circle-stroke-color': '#fff',
    }
}
const CLUSTER_COUNT_LAYER = {
    id: 'cluster-count', type: 'symbol', filter: ['has', 'point_count'],
    layout: { 'text-field': '{point_count_abbreviated}', 'text-size': 12 },
    paint: { 'text-color': '#fff' }
}
const UNCLUSTERED_LAYER = {
    id: 'unclustered-point', type: 'circle', filter: ['!', ['has', 'point_count']],
    paint: {
        'circle-color': ['get', 'markerColor'],
        'circle-radius': ['interpolate', ['linear'], ['zoom'], 9, ['/', _SR, 2], 13, _SR],
        'circle-opacity': 0.88, 'circle-stroke-width': 1, 'circle-stroke-color': 'rgba(255,255,255,0.7)',
    }
}
const ROUTE_CASING_LAYER = {
    id: 'route-casing', type: 'line',
    layout: { 'line-join': 'round', 'line-cap': 'round' },
    paint: { 'line-color': '#ffffff', 'line-width': 9, 'line-opacity': 0.85 }
}
const ROUTE_LINE_LAYER = {
    id: 'route-line', type: 'line',
    layout: { 'line-join': 'round', 'line-cap': 'round' },
    paint: { 'line-color': ['get', 'color'], 'line-width': 5, 'line-opacity': 0.95 }
}
const ROUTING_BASE_URLS = [
    'https://router.project-osrm.org/route/v1/driving',
    'https://routing.openstreetmap.de/routed-car/route/v1/driving',
]
const OSRM_REQUEST_TIMEOUT_MS = 8000
const OSRM_RETRY_COUNT = 1
const OSRM_CHUNK_WAYPOINTS = 8
const ROUTE_CACHE_STORAGE_KEY = 'viz_route_cache_v1'
const ROUTE_CACHE_MAX_ENTRIES = 1500

function isValidCoordPair(p) {
    return Array.isArray(p) && p.length === 2
        && Number.isFinite(Number(p[0]))
        && Number.isFinite(Number(p[1]))
}

function loadPersistentRouteCache() {
    const cache = new globalThis.Map()
    if (typeof window === 'undefined') return cache
    try {
        const raw = window.localStorage.getItem(ROUTE_CACHE_STORAGE_KEY)
        if (!raw) return cache
        const parsed = JSON.parse(raw)
        if (!Array.isArray(parsed)) return cache
        parsed.forEach((entry) => {
            if (!Array.isArray(entry) || entry.length !== 2) return
            const [key, coords] = entry
            if (typeof key !== 'string' || !Array.isArray(coords) || coords.length < 2) return
            if (!coords.every(isValidCoordPair)) return
            cache.set(key, coords)
        })
    } catch {
        // ignore invalid localStorage cache payload
    }
    return cache
}

const ROUTE_GEOMETRY_CACHE = loadPersistentRouteCache()
let routeCachePersistTimer = null

function persistRouteCacheSoon() {
    if (typeof window === 'undefined') return
    if (routeCachePersistTimer) return
    routeCachePersistTimer = window.setTimeout(() => {
        routeCachePersistTimer = null
        try {
            const entries = [...ROUTE_GEOMETRY_CACHE.entries()]
            const tail = entries.slice(Math.max(0, entries.length - ROUTE_CACHE_MAX_ENTRIES))
            window.localStorage.setItem(ROUTE_CACHE_STORAGE_KEY, JSON.stringify(tail))
        } catch {
            // ignore quota/security write errors
        }
    }, 200)
}

function setRouteCacheEntry(key, coords) {
    if (!key || !Array.isArray(coords) || coords.length < 2) return
    if (ROUTE_GEOMETRY_CACHE.has(key)) ROUTE_GEOMETRY_CACHE.delete(key)
    ROUTE_GEOMETRY_CACHE.set(key, coords)
    while (ROUTE_GEOMETRY_CACHE.size > ROUTE_CACHE_MAX_ENTRIES) {
        const oldestKey = ROUTE_GEOMETRY_CACHE.keys().next().value
        if (oldestKey == null) break
        ROUTE_GEOMETRY_CACHE.delete(oldestKey)
    }
    persistRouteCacheSoon()
}

// Urutkan halte mengikuti urutan pemberhentian di data (stopSeq sebagai prioritas).
function toFiniteNumber(value) {
    const n = Number(value)
    return Number.isFinite(n) ? n : null
}

function getStopOrderValue(h) {
    const directSeq = toFiniteNumber(h.stopSeq)
    if (directSeq !== null) return directSeq
    const canonicalPos = toFiniteNumber(h.canonical_pos)
    if (canonicalPos !== null) return canonicalPos
    const seq0 = toFiniteNumber(h.seq_dir_0)
    if (seq0 !== null) return seq0
    const seq1 = toFiniteNumber(h.seq_dir_1)
    if (seq1 !== null) return seq1
    return Number.POSITIVE_INFINITY
}

function sortHalteByStopOrder(pts) {
    return [...pts].sort((a, b) => {
        const orderDiff = getStopOrderValue(a) - getStopOrderValue(b)
        if (orderDiff !== 0) return orderDiff
        return String(a.tapInStopsName || '').localeCompare(String(b.tapInStopsName || ''))
    })
}

function dedupeConsecutiveCoords(coordinates) {
    if (!Array.isArray(coordinates) || coordinates.length <= 1) return coordinates || []
    const result = [coordinates[0]]
    for (let i = 1; i < coordinates.length; i++) {
        const [prevLng, prevLat] = result[result.length - 1]
        const [lng, lat] = coordinates[i]
        if (prevLng !== lng || prevLat !== lat) result.push(coordinates[i])
    }
    return result
}

async function fetchRoadSegment(coordinates) {
    const cleanCoords = dedupeConsecutiveCoords(coordinates)
    if (cleanCoords.length < 2) return cleanCoords

    const coordStr = cleanCoords.map(([lng, lat]) => `${lng},${lat}`).join(';')
    if (ROUTE_GEOMETRY_CACHE.has(coordStr)) return ROUTE_GEOMETRY_CACHE.get(coordStr)

    const tryRequest = async (baseUrl, continueStraight) => {
        const controller = new AbortController()
        const timeoutId = setTimeout(() => controller.abort(), OSRM_REQUEST_TIMEOUT_MS)
        try {
            const url = `${baseUrl}/${coordStr}?overview=full&geometries=geojson&steps=false&continue_straight=${continueStraight ? 'true' : 'false'}`
            const res = await fetch(url, { signal: controller.signal })
            if (!res.ok) throw new Error(`OSRM request failed: ${res.status}`)
            const data = await res.json()
            const routed = data?.routes?.[0]?.geometry?.coordinates
            if (!Array.isArray(routed) || routed.length < 2) throw new Error('OSRM route geometry is empty')
            const cleanRouted = dedupeConsecutiveCoords(routed)
            setRouteCacheEntry(coordStr, cleanRouted)
            return cleanRouted
        } finally {
            clearTimeout(timeoutId)
        }
    }

    let lastErr
    for (let i = 0; i <= OSRM_RETRY_COUNT; i++) {
        for (const baseUrl of ROUTING_BASE_URLS) {
            try {
                return await tryRequest(baseUrl, true)
            } catch (err1) {
                lastErr = err1
                try {
                    return await tryRequest(baseUrl, false)
                } catch (err2) {
                    lastErr = err2
                }
            }
        }
    }
    throw lastErr
}

async function buildRoadSegmentsFromStops(stopsOrdered) {
    const rawCoords = stopsOrdered
        .filter(h => h.latitude != null && h.longitude != null)
        .map(h => [h.longitude, h.latitude])
    const baseCoords = dedupeConsecutiveCoords(rawCoords)

    if (baseCoords.length < 2) return []

    const chunkSize = Math.max(2, OSRM_CHUNK_WAYPOINTS)
    const chunkSegments = []
    for (let start = 0; start < baseCoords.length - 1; start += (chunkSize - 1)) {
        const chunk = baseCoords.slice(start, start + chunkSize)
        if (chunk.length < 2) break
        try {
            const segment = await fetchRoadSegment(chunk)
            if (Array.isArray(segment) && segment.length >= 2) {
                chunkSegments.push(dedupeConsecutiveCoords(segment))
            }
        } catch {
            // no-op, try finer-grained fallback below
        }
        if (start + chunkSize >= baseCoords.length) break
    }

    // If chunk routing succeeded for this corridor, use it (fewer requests, more stable after refresh).
    if (chunkSegments.length > 0) return chunkSegments

    // Fallback: route each adjacent halte pair, keep only successful road segments.
    const routedSegments = []
    for (let i = 1; i < baseCoords.length; i++) {
        const a = baseCoords[i - 1]
        const b = baseCoords[i]
        try {
            const segment = await fetchRoadSegment([a, b])
            if (Array.isArray(segment) && segment.length >= 2) {
                routedSegments.push(dedupeConsecutiveCoords(segment))
            }
        } catch {
            // skip failed segment so route is never drawn as straight "nearest-point" line
        }
    }

    return routedSegments
}

function getSegmentKey(a, b, precision = 5) {
    const norm = ([lng, lat]) => `${Number(lng).toFixed(precision)},${Number(lat).toFixed(precision)}`
    const aKey = norm(a)
    const bKey = norm(b)
    return aKey < bKey ? `${aKey}|${bKey}` : `${bKey}|${aKey}`
}

function collectSegmentKeys(coords, precision = 5) {
    const keys = new Set()
    for (let i = 1; i < coords.length; i++) {
        keys.add(getSegmentKey(coords[i - 1], coords[i], precision))
    }
    return keys
}

function normalizeRouteSegments(route) {
    if (!Array.isArray(route) || route.length === 0) return []
    const first = route[0]
    if (Array.isArray(first) && typeof first[0] === 'number') return [route]
    return route
        .filter((seg) => Array.isArray(seg) && seg.length >= 2)
        .map((seg) => dedupeConsecutiveCoords(seg))
}

function splitRouteBySharedSegments(coords, isSharedSegment, ownColor, includeSharedSegments = true) {
    if (!Array.isArray(coords) || coords.length < 2) return []
    const features = []
    let currentCoords = [coords[0]]
    let currentShared = isSharedSegment(coords[0], coords[1])

    for (let i = 1; i < coords.length; i++) {
        const prev = coords[i - 1]
        const curr = coords[i]
        const segShared = isSharedSegment(prev, curr)
        if (segShared === currentShared) {
            currentCoords.push(curr)
            continue
        }

        if (!currentShared || includeSharedSegments) {
            features.push({
                type: 'Feature',
                geometry: { type: 'LineString', coordinates: currentCoords },
                properties: { color: currentShared ? SHARED_COLOR : ownColor }
            })
        }
        currentCoords = [prev, curr]
        currentShared = segShared
    }

    if ((!currentShared || includeSharedSegments) && currentCoords.length >= 2) {
        features.push({
            type: 'Feature',
            geometry: { type: 'LineString', coordinates: currentCoords },
            properties: { color: currentShared ? SHARED_COLOR : ownColor }
        })
    }

    return features
}

function buildTwoCorridorRouteFeatures(lhsCoords, rhsCoords, precision = 5) {
    const lhsSegments = normalizeRouteSegments(lhsCoords)
    const rhsSegments = normalizeRouteSegments(rhsCoords)
    const lhsKeys = new Set()
    const rhsKeys = new Set()
    lhsSegments.forEach((seg) => {
        collectSegmentKeys(seg, precision).forEach((k) => lhsKeys.add(k))
    })
    rhsSegments.forEach((seg) => {
        collectSegmentKeys(seg, precision).forEach((k) => rhsKeys.add(k))
    })
    const sharedKeys = new Set([...lhsKeys].filter(k => rhsKeys.has(k)))
    const isSharedSegment = (a, b) => sharedKeys.has(getSegmentKey(a, b, precision))

    const lhsFeatures = lhsSegments.flatMap((seg) =>
        splitRouteBySharedSegments(seg, isSharedSegment, CORRIDOR_A_COLOR, true)
    )
    const rhsFeatures = rhsSegments.flatMap((seg) =>
        splitRouteBySharedSegments(seg, isSharedSegment, CORRIDOR_B_COLOR, false)
    )
    return [...lhsFeatures, ...rhsFeatures]
}

export default function MapPage() {
    const [halte, setHalte] = useState([])
    const [rulesAll, setRulesAll] = useState([])
    const [rulesGlobal, setRulesGlobal] = useState([])
    const [clusterStats, setClusterStats] = useState([])

    // filters
    const [selectedCluster, setSelectedCluster] = useState('all')
    const [searchText, setSearchText] = useState('')
    const [viewMode, setViewMode] = useState('cluster')
    const [sortField, setSortField] = useState('lift')

    // rule selection
    const [selectedRuleIdx, setSelectedRuleIdx] = useState(null)
    const [selectedHalte, setSelectedHalte] = useState(null)

    // right sidebar
    const [rightSidebarOpen, setRightSidebarOpen] = useState(false)
    const rightSidebarContentRef = useRef(null)
    const halteItemRefs = useRef(new globalThis.Map())

    // map-specific state
    const mapRef = useRef(null)
    const [popupInfo, setPopupInfo] = useState(null)        // { longitude, latitude, halte }
    const [mapStyleKey, setMapStyleKey] = useState('positron')
    const [displayMode, setDisplayMode] = useState('points') // 'points' | 'heatmap' | 'clusters'
    const [viewState, setViewState] = useState({ longitude: 106.85, latitude: -6.2, zoom: 11 })
    const [routeGeoJSON, setRouteGeoJSON] = useState(null)

    const [loading, setLoading] = useState(true)

    useEffect(() => {
        Promise.all([
            loadCSV('/data/halte.csv'),
            loadCSV('/data/rules_all_cross.csv'),
            loadCSV('/data/rules_global_cross.csv'),
            loadCSV('/data/cluster_stats.csv'),
        ]).then(([h, ra, rg, cs]) => {
            setHalte(normalizeCorridorField(h, 'corridorName'))
            const norm = rules => rules
                .map(r => ({ ...r, lhs: normalizeCorridor(r.lhs), rhs: normalizeCorridor(r.rhs) }))
                .filter(r => r.lhs && r.rhs && r.lhs !== r.rhs)
            setRulesAll(filterRulesByMaxSupportConfidence(norm(ra), 0.8))
            setRulesGlobal(filterRulesByMaxSupportConfidence(norm(rg), 0.8))
            setClusterStats(cs)
            setLoading(false)
        })
    }, [])

    /* ── active rules based on mode ── */
    const activeRules = viewMode === 'global' ? rulesGlobal : rulesAll

    /* ── filtered rules ── */
    const filteredRules = useMemo(() => {
        let rules = activeRules
        if (viewMode === 'cluster' && selectedCluster !== 'all') {
            rules = rules.filter(r => r.cluster === Number(selectedCluster))
        }
        if (searchText.trim()) {
            const q = searchText.toLowerCase()
            rules = rules.filter(r => r.lhs.toLowerCase().includes(q) || r.rhs.toLowerCase().includes(q))
        }
        return [...rules].sort((a, b) => (b[sortField] ?? 0) - (a[sortField] ?? 0))
    }, [activeRules, selectedCluster, searchText, sortField, viewMode])

    /* ── selected rule ── */
    const selectedRule = selectedRuleIdx !== null ? filteredRules[selectedRuleIdx] : null

    /* ── corridors per cluster ── */
    const clusterCorridors = useMemo(() => {
        const m = {}
        rulesAll.forEach(r => {
            const cl = r.cluster
            if (!m[cl]) m[cl] = new Set()
            m[cl].add(r.lhs)
            m[cl].add(r.rhs)
        })
        return m
    }, [rulesAll])

    /* ── halte for the selected rule's two corridors ── */
    const ruleHalteLHS = useMemo(() => {
        if (!selectedRule) return []
        return sortHalteByStopOrder(halte.filter(h => h.corridorName === selectedRule.lhs))
    }, [halte, selectedRule])

    const ruleHalteRHS = useMemo(() => {
        if (!selectedRule) return []
        return sortHalteByStopOrder(halte.filter(h => h.corridorName === selectedRule.rhs))
    }, [halte, selectedRule])

    const sharedHalte = useMemo(() => {
        if (!selectedRule) return []
        const lhsNames = new Set(ruleHalteLHS.map(h => h.tapInStopsName))
        return ruleHalteRHS.filter(h => lhsNames.has(h.tapInStopsName))
    }, [ruleHalteLHS, ruleHalteRHS, selectedRule])

    /* ── top halte per corridor ── */
    const topHalteLHS = useMemo(() =>
        [...ruleHalteLHS].sort((a, b) => (b.total_penumpang_bulan || 0) - (a.total_penumpang_bulan || 0)).slice(0, 3),
        [ruleHalteLHS]
    )
    const topHalteRHS = useMemo(() =>
        [...ruleHalteRHS].sort((a, b) => (b.total_penumpang_bulan || 0) - (a.total_penumpang_bulan || 0)).slice(0, 3),
        [ruleHalteRHS]
    )

    /* ── corridor stats ── */
    const corridorStatsLHS = useMemo(() => {
        if (!ruleHalteLHS.length) return null
        const total = ruleHalteLHS.reduce((s, h) => s + (h.total_penumpang_bulan || 0), 0)
        return { totalHalte: ruleHalteLHS.length, totalPenumpang: total, avgPenumpang: total / ruleHalteLHS.length }
    }, [ruleHalteLHS])

    const corridorStatsRHS = useMemo(() => {
        if (!ruleHalteRHS.length) return null
        const total = ruleHalteRHS.reduce((s, h) => s + (h.total_penumpang_bulan || 0), 0)
        return { totalHalte: ruleHalteRHS.length, totalPenumpang: total, avgPenumpang: total / ruleHalteRHS.length }
    }, [ruleHalteRHS])

    /* ── default halte (no rule selected) ── */
    const defaultFilteredHalte = useMemo(() => {
        if (selectedCluster === 'all') return halte
        const corridors = clusterCorridors[selectedCluster]
        if (!corridors) return halte
        return halte.filter(h => corridors.has(h.corridorName))
    }, [halte, selectedCluster, clusterCorridors])

    /* ── displayed halte — must be memoized or fitBounds useEffect loops ── */
    const displayedHalte = useMemo(
        () => selectedRule ? [...ruleHalteLHS, ...ruleHalteRHS] : defaultFilteredHalte,
        [selectedRule, ruleHalteLHS, ruleHalteRHS, defaultFilteredHalte]
    )

    /* ── unique corridors list ── */
    const corridorList = useMemo(() => {
        const set = new Set(halte.map(h => h.corridorName))
        return [...set].sort()
    }, [halte])

    /* ── marker helpers ── */
    const getMarkerColor = useCallback((h) => {
        if (selectedRule) {
            const isLHS = h.corridorName === selectedRule.lhs
            const isRHS = h.corridorName === selectedRule.rhs
            // A halte record belongs to ONE corridor, but its name may also appear
            // in the other corridor → that’s “shared”
            const sharedNames = new Set(sharedHalte.map(s => s.tapInStopsName))
            if (sharedNames.has(h.tapInStopsName)) return SHARED_COLOR
            if (isLHS) return CORRIDOR_A_COLOR
            if (isRHS) return CORRIDOR_B_COLOR
            return '#ccc'
        }
        if (selectedCluster !== 'all') return CLUSTER_COLORS[selectedCluster] || '#666'
        return CLUSTER_COLORS[h.cluster] || '#3388ff'
    }, [selectedRule, selectedCluster, sharedHalte])

    const getRadius = useCallback((h) => {
        const val = h.total_penumpang_bulan || 1
        if (selectedRule) return Math.max(7, Math.min(22, Math.sqrt(val) / 2.0))
        return Math.max(3, Math.min(12, Math.sqrt(val) / 3))
    }, [selectedRule])

    /* ── build GeoJSON for MapLibre Source ── */
    const halteGeoJSON = useMemo(() => ({
        type: 'FeatureCollection',
        features: displayedHalte
            .filter(h => h.latitude != null && h.longitude != null)
            .map(h => ({
                type: 'Feature',
                geometry: { type: 'Point', coordinates: [h.longitude, h.latitude] },
                properties: {
                    tapInStopsName: h.tapInStopsName,
                    corridorName: h.corridorName,
                    corridorID: h.corridorID,
                    total_penumpang_bulan: h.total_penumpang_bulan || 0,
                    rata_rata_per_hari: h.rata_rata_per_hari || 0,
                    markerColor: getMarkerColor(h),
                    radius: getRadius(h),
                    isSelected: selectedHalte?.tapInStopsName === h.tapInStopsName ? 1 : 0,
                    inRuleMode: selectedRule ? 1 : 0,
                }
            }))
    }), [displayedHalte, getMarkerColor, getRadius, selectedHalte])

    /* ── fit bounds when displayed halte changes (animated) ── */
    useEffect(() => {
        if (!mapRef.current) return
        const pts = displayedHalte.filter(h => h.latitude != null && h.longitude != null)
        if (pts.length === 0) return
        const lngs = pts.map(h => h.longitude)
        const lats = pts.map(h => h.latitude)
        const west = Math.min(...lngs), east = Math.max(...lngs)
        const south = Math.min(...lats), north = Math.max(...lats)
        mapRef.current.fitBounds(
            [[west, south], [east, north]],
            { padding: 60, maxZoom: 15, duration: 900 }
        )
    }, [displayedHalte])

    /* ── route GeoJSON for selected rule corridors (follow roads via OSRM) ── */
    useEffect(() => {
        let cancelled = false

        if (!selectedRule) {
            setRouteGeoJSON(null)
            return () => { }
        }
        setRouteGeoJSON(null)

        const buildRoute = async () => {
            // Sequential to reduce burst requests to public OSRM and lower timeout risk.
            const lhsRoadCoords = await buildRoadSegmentsFromStops(ruleHalteLHS)
            const rhsRoadCoords = await buildRoadSegmentsFromStops(ruleHalteRHS)
            if (cancelled) return

            const features = buildTwoCorridorRouteFeatures(lhsRoadCoords, rhsRoadCoords)

            setRouteGeoJSON(features.length ? { type: 'FeatureCollection', features } : null)
        }

        buildRoute().catch(() => {
            if (!cancelled) setRouteGeoJSON(null)
        })

        return () => {
            cancelled = true
        }
    }, [selectedRule, ruleHalteLHS, ruleHalteRHS])

    const flyToHalte = useCallback((h) => {
        if (!mapRef.current || !h || h.latitude == null || h.longitude == null) return
        mapRef.current.flyTo({
            center: [h.longitude, h.latitude],
            zoom: Math.max(viewState.zoom || 11, 13),
            duration: 700,
            essential: true,
        })
    }, [viewState.zoom])

    useEffect(() => {
        if (!selectedHalte) return
        const key = `${selectedHalte.corridorName}__${selectedHalte.tapInStopsName}`
        const el = halteItemRefs.current.get(key)
        if (el && typeof el.scrollIntoView === 'function') {
            el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        } else if (rightSidebarContentRef.current) {
            rightSidebarContentRef.current.scrollTo({ top: 0, behavior: 'smooth' })
        }
    }, [selectedHalte, selectedRule])

    /* ── event handlers ── */
    const handleRuleClick = (idx) => {
        if (selectedRuleIdx === idx) {
            setSelectedRuleIdx(null)
            setRightSidebarOpen(false)
            setSelectedHalte(null)
            setPopupInfo(null)
        } else {
            setSelectedRuleIdx(idx)
            setRightSidebarOpen(true)
            setSelectedHalte(null)
            setPopupInfo(null)
            // force points mode when rule is selected
            setDisplayMode('points')
        }
    }

    const handleHalteClick = useCallback((h) => {
        setSelectedHalte(h)
        setRightSidebarOpen(true)
        flyToHalte(h)
    }, [flyToHalte])

    /* ── map click ── */
    const handleMapClick = useCallback((e) => {
        const features = e.features
        if (!features || features.length === 0) {
            setPopupInfo(null)
            return
        }
        const props = features[0].properties
        const h = halte.find(h => h.tapInStopsName === props.tapInStopsName && h.corridorName === props.corridorName)
        if (h) {
            setPopupInfo({ longitude: h.longitude, latitude: h.latitude, halte: h })
            handleHalteClick(h)
        }
    }, [halte, handleHalteClick])

    const interactiveLayers = displayMode === 'clusters'
        ? ['clusters', 'unclustered-point']
        : ['halte-circles']

    if (loading) return (
        <div className="loading">
            <div className="loading-spinner" />
            <span>Memuat data peta...</span>
        </div>
    )

    return (
        <div className="map-page">
            {/* ══════ LEFT SIDEBAR ══════ */}
            <div className="map-sidebar-left">
                <div className="sidebar-section">
                    <div className="sidebar-title">
                        <span>🔍 Filter & Rules</span>
                    </div>

                    {/* Mode toggle */}
                    <div className="filter-section">
                        <label>Mode Rules</label>
                        <div className="btn-group-sm">
                            <button className={`btn-sm ${viewMode === 'cluster' ? 'active' : ''}`} onClick={() => { setViewMode('cluster'); setSelectedRuleIdx(null) }}>Cluster</button>
                            <button className={`btn-sm ${viewMode === 'global' ? 'active' : ''}`} onClick={() => { setViewMode('global'); setSelectedRuleIdx(null) }}>Global</button>
                        </div>
                    </div>

                    {/* Cluster filter */}
                    {viewMode === 'cluster' && (
                        <div className="filter-section">
                            <label>Cluster</label>
                            <select value={selectedCluster} onChange={e => { setSelectedCluster(e.target.value); setSelectedRuleIdx(null) }}>
                                <option value="all">Semua Cluster</option>
                                {[1, 2, 3, 4, 5].map(c => (
                                    <option key={c} value={c}>C{c}: {CLUSTER_LABELS[c]}</option>
                                ))}
                            </select>
                        </div>
                    )}

                    {/* Sort */}
                    <div className="filter-section">
                        <label>Urutkan</label>
                        <select value={sortField} onChange={e => setSortField(e.target.value)}>
                            <option value="lift">Lift (tertinggi)</option>
                            <option value="confidence">Confidence</option>
                            <option value="support">Support</option>
                        </select>
                    </div>

                    {/* Search */}
                    <div className="filter-section">
                        <label>Cari Koridor</label>
                        <input type="text" placeholder="Ketik nama koridor..." value={searchText} onChange={e => setSearchText(e.target.value)} />
                    </div>
                </div>

                {/* Cluster info quick card */}
                {selectedCluster !== 'all' && viewMode === 'cluster' && (
                    <div className="sidebar-section">
                        {clusterStats.filter(cs => cs.cluster === Number(selectedCluster)).map(cs => (
                            <div key={cs.cluster} className="cluster-quick-card" style={{ borderLeft: `4px solid ${CLUSTER_COLORS[cs.cluster]}` }}>
                                <div className="cqc-label" style={{ color: CLUSTER_COLORS[cs.cluster] }}>{cs.label}</div>
                                <div className="cqc-stats">
                                    <div><strong>{Number(cs.n_total).toLocaleString()}</strong> trips</div>
                                    <div><strong>{Number(cs.n_users).toLocaleString()}</strong> users</div>
                                    <div>Cross: <strong>{cs.pct_cross}%</strong></div>
                                </div>
                            </div>
                        ))}
                    </div>
                )}

                {/* Rules list */}
                <div className="sidebar-section rules-section">
                    <div className="sidebar-title">
                        <span>📋 Rules ({filteredRules.length})</span>
                        {selectedRuleIdx !== null && (
                            <button className="btn-clear-sm" onClick={() => { setSelectedRuleIdx(null); setRightSidebarOpen(false); setSelectedHalte(null); setPopupInfo(null) }}>
                                ✕ Clear
                            </button>
                        )}
                    </div>
                    <div className="rules-scroll">
                        {filteredRules.length === 0 ? (
                            <div className="no-data">Tidak ada rules ditemukan</div>
                        ) : (
                            filteredRules.map((r, i) => (
                                <div
                                    key={i}
                                    className={`rule-card-v2 ${selectedRuleIdx === i ? 'selected' : ''}`}
                                    onClick={() => handleRuleClick(i)}
                                    style={{ '--rule-color': CLUSTER_COLORS[r.cluster] || '#3498db' }}
                                >
                                    <div className="rcv2-corridors">
                                        <span className="rcv2-lhs">{r.lhs}</span>
                                        <span className="rcv2-arrow">→</span>
                                        <span className="rcv2-rhs">{r.rhs}</span>
                                    </div>
                                    <div className="rcv2-metrics">
                                        <span className="rcv2-metric"><strong>{r.lift?.toFixed(1)}</strong> lift</span>
                                        <span className="rcv2-metric">{(r.confidence * 100).toFixed(0)}% conf</span>
                                        <span className="rcv2-metric">{(r.support * 100).toFixed(2)}% sup</span>
                                    </div>
                                    {viewMode === 'cluster' && (
                                        <span className="rcv2-cluster-tag" style={{ background: CLUSTER_COLORS[r.cluster] }}>C{r.cluster}</span>
                                    )}
                                </div>
                            ))
                        )}
                    </div>
                </div>

                {/* Legend */}
                <div className="sidebar-section sidebar-legend">
                    <div className="sidebar-title"><span>🎨 Legend</span></div>
                    {selectedRule ? (
                        <>
                            <div className="legend-item"><span className="legend-dot" style={{ background: CORRIDOR_A_COLOR }} />Koridor A (LHS)</div>
                            <div className="legend-item"><span className="legend-dot" style={{ background: CORRIDOR_B_COLOR }} />Koridor B (RHS)</div>
                            <div className="legend-item"><span className="legend-dot" style={{ background: SHARED_COLOR }} />Halte bersama</div>
                        </>
                    ) : (
                        Object.entries(CLUSTER_LABELS).map(([k, v]) => (
                            <div key={k} className="legend-item">
                                <span className="legend-dot" style={{ background: CLUSTER_COLORS[k] }} />C{k}: {v}
                            </div>
                        ))
                    )}
                    <div className="legend-note">Ukuran titik = jumlah penumpang</div>
                </div>
            </div>

            {/* ══════ MAP ══════ */}
            <div className="map-center">
                {/* Map toolbar */}
                <div className="map-toolbar">
                    {!selectedRule && (
                        <div className="map-toolbar-group">
                            <span className="map-toolbar-label">Tampilan</span>
                            <div className="btn-group-sm">
                                <button className={`btn-sm ${displayMode === 'points' ? 'active' : ''}`} onClick={() => setDisplayMode('points')}>● Titik</button>
                                <button className={`btn-sm ${displayMode === 'heatmap' ? 'active' : ''}`} onClick={() => setDisplayMode('heatmap')}>🌡 Heatmap</button>
                                <button className={`btn-sm ${displayMode === 'clusters' ? 'active' : ''}`} onClick={() => setDisplayMode('clusters')}>⬟ Cluster</button>
                            </div>
                        </div>
                    )}
                    <div className="map-toolbar-group">
                        <span className="map-toolbar-label">Gaya Peta</span>
                        <div className="btn-group-sm">
                            <button className={`btn-sm ${mapStyleKey === 'liberty' ? 'active' : ''}`} onClick={() => setMapStyleKey('liberty')}>Liberty</button>
                            <button className={`btn-sm ${mapStyleKey === 'positron' ? 'active' : ''}`} onClick={() => setMapStyleKey('positron')}>Positron</button>
                            <button className={`btn-sm ${mapStyleKey === 'bright' ? 'active' : ''}`} onClick={() => setMapStyleKey('bright')}>Bright</button>
                        </div>
                    </div>
                </div>

                <Map
                    ref={mapRef}
                    {...viewState}
                    onMove={e => setViewState(e.viewState)}
                    style={{ width: '100%', height: '100%' }}
                    mapStyle={MAP_STYLES[mapStyleKey]}
                    interactiveLayerIds={interactiveLayers}
                    onClick={handleMapClick}
                    cursor="grab"
                >
                    <NavigationControl position="top-right" />
                    <ScaleControl position="bottom-right" />
                    <FullscreenControl position="top-right" />

                    {/* ── HEATMAP mode ── */}
                    {!selectedRule && displayMode === 'heatmap' && (
                        <Source id="halte-source" type="geojson" data={halteGeoJSON}>
                            <Layer {...HEATMAP_LAYER} />
                        </Source>
                    )}

                    {/* ── CLUSTER mode ── */}
                    {!selectedRule && displayMode === 'clusters' && (
                        <Source id="halte-source" type="geojson" data={halteGeoJSON} cluster clusterMaxZoom={14} clusterRadius={50}>
                            <Layer {...CLUSTER_CIRCLE_LAYER} />
                            <Layer {...CLUSTER_COUNT_LAYER} />
                            <Layer {...UNCLUSTERED_LAYER} />
                        </Source>
                    )}

                    {/* ── ROUTE lines when rule selected (rendered before halte so dots appear on top) ── */}
                    {selectedRule && routeGeoJSON && (
                        <Source id="route-source" type="geojson" data={routeGeoJSON}>
                            <Layer {...ROUTE_CASING_LAYER} />
                            <Layer {...ROUTE_LINE_LAYER} />
                        </Source>
                    )}

                    {/* ── POINTS mode (default + rule mode) ── */}
                    {(displayMode === 'points' || selectedRule) && (
                        <Source id="halte-source" type="geojson" data={halteGeoJSON}>
                            <Layer {...CIRCLE_LAYER} />
                        </Source>
                    )}

                    {/* ── Click popup ── */}
                    {popupInfo && (
                        <Popup
                            longitude={popupInfo.longitude}
                            latitude={popupInfo.latitude}
                            offset={14}
                            closeButton
                            onClose={() => setPopupInfo(null)}
                            anchor="bottom"
                        >
                            <div style={{ minWidth: 210, fontSize: '0.85rem' }}>
                                <strong style={{ fontSize: '0.95rem', display: 'block', marginBottom: 4 }}>{popupInfo.halte.tapInStopsName}</strong>
                                <span style={{ color: '#666' }}>{popupInfo.halte.corridorName}</span>
                                <hr style={{ margin: '6px 0', border: 'none', borderTop: '1px solid #eee' }} />
                                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 4 }}>
                                    <span style={{ color: '#888' }}>Koridor ID</span><strong>{popupInfo.halte.corridorID}</strong>
                                    <span style={{ color: '#888' }}>Penumpang/bln</span><strong>{popupInfo.halte.total_penumpang_bulan?.toLocaleString()}</strong>
                                    <span style={{ color: '#888' }}>Koordinat</span><strong style={{ fontSize: '0.75rem' }}>{popupInfo.halte.latitude?.toFixed(4)}, {popupInfo.halte.longitude?.toFixed(4)}</strong>
                                </div>
                            </div>
                        </Popup>
                    )}
                </Map>

                {/* Stats bar */}
                <div className="map-stats-bar">
                    {selectedRule ? (
                        <>
                            <span><span style={{ color: CORRIDOR_A_COLOR }}>■</span> {selectedRule.lhs}</span>
                            <span className="msb-arrow">→</span>
                            <span><span style={{ color: CORRIDOR_B_COLOR }}>■</span> {selectedRule.rhs}</span>
                            <span className="msb-sep">|</span>
                            <span>Lift: <strong>{selectedRule.lift?.toFixed(2)}</strong></span>
                            <span className="msb-sep">|</span>
                            <span style={{ color: CORRIDOR_A_COLOR }}>A: {ruleHalteLHS.length} halte</span>
                            <span className="msb-sep">·</span>
                            <span style={{ color: CORRIDOR_B_COLOR }}>B: {ruleHalteRHS.length} halte</span>
                            {sharedHalte.length > 0 && <><span className="msb-sep">·</span><span style={{ color: SHARED_COLOR }}>{sharedHalte.length} bersama</span></>}
                        </>
                    ) : (
                        <>
                            <span><strong>{displayedHalte.length.toLocaleString()}</strong> halte ditampilkan</span>
                            {selectedCluster !== 'all' && <span>· C{selectedCluster}: {CLUSTER_LABELS[selectedCluster]}</span>}
                            <span className="msb-sep">|</span>
                            <span style={{ textTransform: 'capitalize', color: '#94a3b8', fontSize: '0.78rem' }}>{displayMode}</span>
                        </>
                    )}
                </div>
            </div>

            {/* ══════ RIGHT SIDEBAR ══════ */}
            <div className={`map-sidebar-right ${rightSidebarOpen ? 'open' : ''}`}>
                <div className="sidebar-right-toggle" onClick={() => setRightSidebarOpen(!rightSidebarOpen)}>
                    {rightSidebarOpen ? '▶' : '◀'}
                </div>

                {selectedRule ? (
                    <div className="right-sidebar-content" ref={rightSidebarContentRef}>
                        <div className="rs-section">
                            <div className="rs-title">📊 Detail Rule</div>
                            <div className="rs-rule-display">
                                <div className="rs-corridor-a" style={{ borderColor: CORRIDOR_A_COLOR }}>
                                    <span className="rs-corridor-label" style={{ color: CORRIDOR_A_COLOR }}>Koridor A (LHS)</span>
                                    <span className="rs-corridor-name">{selectedRule.lhs}</span>
                                </div>
                                <div className="rs-arrow-big">→</div>
                                <div className="rs-corridor-b" style={{ borderColor: CORRIDOR_B_COLOR }}>
                                    <span className="rs-corridor-label" style={{ color: CORRIDOR_B_COLOR }}>Koridor B (RHS)</span>
                                    <span className="rs-corridor-name">{selectedRule.rhs}</span>
                                </div>
                            </div>
                        </div>

                        <div className="rs-section">
                            <div className="rs-title">📈 Metrik Asosiasi</div>
                            <div className="rs-metrics-grid">
                                <div className="rs-metric"><span className="rs-metric-val">{selectedRule.lift?.toFixed(2)}</span><span className="rs-metric-label">Lift</span></div>
                                <div className="rs-metric"><span className="rs-metric-val">{(selectedRule.confidence * 100).toFixed(1)}%</span><span className="rs-metric-label">Confidence</span></div>
                                <div className="rs-metric"><span className="rs-metric-val">{(selectedRule.support * 100).toFixed(3)}%</span><span className="rs-metric-label">Support</span></div>
                            </div>
                        </div>

                        <div className="rs-section">
                            <div className="rs-title" style={{ color: CORRIDOR_A_COLOR }}>■ Koridor A Stats</div>
                            {corridorStatsLHS && (
                                <div className="rs-corridor-stats">
                                    <div className="rs-cs-row"><span>Jumlah Halte</span><strong>{corridorStatsLHS.totalHalte}</strong></div>
                                    <div className="rs-cs-row"><span>Total Penumpang/Bulan</span><strong>{corridorStatsLHS.totalPenumpang.toLocaleString()}</strong></div>
                                </div>
                            )}
                            <div className="rs-subtitle">🏆 Top 3 Halte</div>
                                <div className="rs-top-halte">
                                    {topHalteLHS.map((h, i) => (
                                    <div
                                        key={i}
                                        ref={(el) => {
                                            const key = `${h.corridorName}__${h.tapInStopsName}`
                                            if (el) halteItemRefs.current.set(key, el)
                                            else halteItemRefs.current.delete(key)
                                        }}
                                        className={`rs-halte-item ${selectedHalte?.tapInStopsName === h.tapInStopsName ? 'active' : ''}`}
                                        onClick={() => handleHalteClick(h)}
                                    >
                                        <span className="rs-halte-rank">#{i + 1}</span>
                                        <div className="rs-halte-info">
                                            <span className="rs-halte-name">{h.tapInStopsName}</span>
                                            <span className="rs-halte-val">{h.total_penumpang_bulan?.toLocaleString()} penumpang</span>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="rs-section">
                            <div className="rs-title" style={{ color: CORRIDOR_B_COLOR }}>■ Koridor B Stats</div>
                            {corridorStatsRHS && (
                                <div className="rs-corridor-stats">
                                    <div className="rs-cs-row"><span>Jumlah Halte</span><strong>{corridorStatsRHS.totalHalte}</strong></div>
                                    <div className="rs-cs-row"><span>Total Penumpang/Bulan</span><strong>{corridorStatsRHS.totalPenumpang.toLocaleString()}</strong></div>
                                </div>
                            )}
                            <div className="rs-subtitle">🏆 Top 3 Halte</div>
                            <div className="rs-top-halte">
                                {topHalteRHS.map((h, i) => (
                                    <div
                                        key={i}
                                        ref={(el) => {
                                            const key = `${h.corridorName}__${h.tapInStopsName}`
                                            if (el) halteItemRefs.current.set(key, el)
                                            else halteItemRefs.current.delete(key)
                                        }}
                                        className={`rs-halte-item ${selectedHalte?.tapInStopsName === h.tapInStopsName ? 'active' : ''}`}
                                        onClick={() => handleHalteClick(h)}
                                    >
                                        <span className="rs-halte-rank">#{i + 1}</span>
                                        <div className="rs-halte-info">
                                            <span className="rs-halte-name">{h.tapInStopsName}</span>
                                            <span className="rs-halte-val">{h.total_penumpang_bulan?.toLocaleString()} penumpang</span>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        {sharedHalte.length > 0 && (
                            <div className="rs-section">
                                <div className="rs-title" style={{ color: SHARED_COLOR }}>■ Halte Bersama ({sharedHalte.length})</div>
                                <div className="rs-shared-list">
                                    {sharedHalte.map((h, i) => (
                                        <div
                                            key={i}
                                            ref={(el) => {
                                                const key = `${h.corridorName}__${h.tapInStopsName}`
                                                if (el) halteItemRefs.current.set(key, el)
                                                else halteItemRefs.current.delete(key)
                                            }}
                                            className="rs-shared-item"
                                            onClick={() => handleHalteClick(h)}
                                        >
                                            {h.tapInStopsName}
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}

                        <div className="rs-section">
                            <div className="rs-title">⚖️ Perbandingan</div>
                            <div className="rs-comparison">
                                <div className="rs-comp-row"><span></span><span style={{ color: CORRIDOR_A_COLOR, fontWeight: 600 }}>Kor. A</span><span style={{ color: CORRIDOR_B_COLOR, fontWeight: 600 }}>Kor. B</span></div>
                                <div className="rs-comp-row"><span>Halte</span><span>{ruleHalteLHS.length}</span><span>{ruleHalteRHS.length}</span></div>
                                <div className="rs-comp-row"><span>Total Penumpang</span><span>{corridorStatsLHS?.totalPenumpang.toLocaleString()}</span><span>{corridorStatsRHS?.totalPenumpang.toLocaleString()}</span></div>
                                <div className="rs-comp-row"><span>Top Halte</span><span>{topHalteLHS[0]?.tapInStopsName || '-'}</span><span>{topHalteRHS[0]?.tapInStopsName || '-'}</span></div>
                            </div>
                        </div>
                    </div>
                ) : selectedHalte ? (
                    <div className="right-sidebar-content" ref={rightSidebarContentRef}>
                        <div className="rs-section">
                            <div className="rs-title">📍 Detail Halte</div>
                            <div className="rs-halte-detail">
                                <h4>{selectedHalte.tapInStopsName}</h4>
                                <div className="rs-hd-row"><span>Koridor</span><strong>{selectedHalte.corridorName}</strong></div>
                                <div className="rs-hd-row"><span>Koridor ID</span><strong>{selectedHalte.corridorID}</strong></div>
                                <div className="rs-hd-row"><span>Penumpang/Bulan</span><strong>{selectedHalte.total_penumpang_bulan?.toLocaleString()}</strong></div>
                                <div className="rs-hd-row"><span>Rata-rata/Hari</span><strong>{selectedHalte.rata_rata_per_hari}</strong></div>
                                <div className="rs-hd-row"><span>Koordinat</span><strong style={{ fontSize: '0.78rem' }}>{selectedHalte.latitude?.toFixed(6)}, {selectedHalte.longitude?.toFixed(6)}</strong></div>
                            </div>
                        </div>
                        <div className="rs-section">
                            <div className="rs-title">🚏 Halte Lain di Koridor Ini</div>
                            <div className="rs-other-halte">
                                {halte
                                    .filter(h => h.corridorName === selectedHalte.corridorName && h.tapInStopsName !== selectedHalte.tapInStopsName)
                                    .sort((a, b) => {
                                        const orderDiff = getStopOrderValue(a) - getStopOrderValue(b)
                                        if (orderDiff !== 0) return orderDiff
                                        return (b.total_penumpang_bulan || 0) - (a.total_penumpang_bulan || 0)
                                    })
                                    .slice(0, 8)
                                    .map((h, i) => (
                                        <div
                                            key={i}
                                            ref={(el) => {
                                                const key = `${h.corridorName}__${h.tapInStopsName}`
                                                if (el) halteItemRefs.current.set(key, el)
                                                else halteItemRefs.current.delete(key)
                                            }}
                                            className="rs-other-item"
                                            onClick={() => handleHalteClick(h)}
                                        >
                                            <span>{h.tapInStopsName}</span>
                                            <span className="rs-other-val">{h.total_penumpang_bulan?.toLocaleString()}</span>
                                        </div>
                                    ))
                                }
                            </div>
                        </div>
                    </div>
                ) : (
                    <div className="right-sidebar-content" ref={rightSidebarContentRef}>
                        <div className="rs-section">
                            <div className="rs-empty">
                                <div className="rs-empty-icon">👆</div>
                                <p>Pilih rule dari panel kiri atau klik halte di peta untuk melihat detail</p>
                            </div>
                        </div>
                        <div className="rs-section">
                            <div className="rs-title">📊 Statistik</div>
                            <div className="rs-quick-stats">
                                <div className="rs-qs-item"><span>Total Halte</span><strong>{halte.length.toLocaleString()}</strong></div>
                                <div className="rs-qs-item"><span>Koridor Unik</span><strong>{corridorList.length}</strong></div>
                                <div className="rs-qs-item"><span>Rules (Cluster)</span><strong>{rulesAll.length}</strong></div>
                                <div className="rs-qs-item"><span>Rules (Global)</span><strong>{rulesGlobal.length}</strong></div>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    )
}
