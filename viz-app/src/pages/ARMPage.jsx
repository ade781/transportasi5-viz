import { useState, useEffect, useMemo } from 'react'
import {
    BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
    ResponsiveContainer, Cell, ScatterChart, Scatter, ZAxis,
    PieChart, Pie, RadarChart, Radar, PolarGrid, PolarAngleAxis,
    PolarRadiusAxis
} from 'recharts'
import {
    loadCSV,
    CLUSTER_COLORS,
    CLUSTER_LABELS,
    normalizeCorridor,
    filterRulesByMaxSupportConfidence
} from '../utils'

function StatCard({ label, value, sub, color, icon }) {
    return (
        <div className="stat-card" style={{ borderLeft: `4px solid ${color || '#3498db'}` }}>
            <div className="stat-card-top">
                {icon && <span className="stat-card-icon">{icon}</span>}
                <span className="stat-card-label">{label}</span>
            </div>
            <div className="stat-card-value" style={{ color: color || '#2c3e50' }}>{value}</div>
            {sub && <div className="stat-card-sub">{sub}</div>}
        </div>
    )
}

function Section({ title, subtitle, children }) {
    return (
        <section className="gmm-section">
            <div className="section-header">
                <h3>{title}</h3>
                {subtitle && <p className="section-subtitle">{subtitle}</p>}
            </div>
            {children}
        </section>
    )
}

export default function ARMPage() {
    const [rulesAll, setRulesAll] = useState([])
    const [rulesGlobal, setRulesGlobal] = useState([])
    const [armSummary, setArmSummary] = useState([])
    const [armEval, setArmEval] = useState([])
    const [clusterStats, setClusterStats] = useState([])
    const [armFilterParams, setArmFilterParams] = useState([])
    const [selectedCluster, setSelectedCluster] = useState('all')
    const [searchText, setSearchText] = useState('')
    const [sortField, setSortField] = useState('lift')
    const [sortDir, setSortDir] = useState('desc')
    const [viewMode, setViewMode] = useState('cluster')
    const [activeTab, setActiveTab] = useState('overview')
    const [selectedRule, setSelectedRule] = useState(null)
    const [minLift, setMinLift] = useState(0)
    const [minConf, setMinConf] = useState(0)
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        Promise.all([
            loadCSV('/data/rules_all.csv'),
            loadCSV('/data/rules_global.csv'),
            loadCSV('/data/arm_summary.csv'),
            loadCSV('/data/arm_evaluation.csv'),
            loadCSV('/data/arm_evaluation_cluster.csv'),
            loadCSV('/data/cluster_stats.csv'),
            loadCSV('/data/arm_filter_params.csv'),
        ]).then(([ra, rg, as_, ae, _aec, cs, fp]) => {
            const normalizeRules = (rules) => rules.map(r => ({
                ...r,
                lhs: normalizeCorridor(r.lhs),
                rhs: normalizeCorridor(r.rhs),
            }))
            setRulesAll(filterRulesByMaxSupportConfidence(normalizeRules(ra), 0.8))
            setRulesGlobal(filterRulesByMaxSupportConfidence(normalizeRules(rg), 0.8))
            setArmSummary(as_)
            setArmEval(ae)
            setClusterStats(cs)
            setArmFilterParams(fp)
            setLoading(false)
        })
    }, [])

    const activeRules = viewMode === 'global' ? rulesGlobal : rulesAll

    const filteredRules = useMemo(() => {
        let rules = activeRules
        if (viewMode === 'cluster' && selectedCluster !== 'all') {
            rules = rules.filter(r => r.cluster === Number(selectedCluster))
        }
        if (searchText.trim()) {
            const q = searchText.toLowerCase()
            rules = rules.filter(r =>
                (r.lhs || '').toLowerCase().includes(q) || (r.rhs || '').toLowerCase().includes(q)
            )
        }
        if (minLift > 0) rules = rules.filter(r => r.lift >= minLift)
        if (minConf > 0) rules = rules.filter(r => r.confidence >= minConf)

        rules = [...rules].sort((a, b) => {
            const aVal = a[sortField] ?? 0
            const bVal = b[sortField] ?? 0
            return sortDir === 'desc' ? bVal - aVal : aVal - bVal
        })
        return rules
    }, [activeRules, selectedCluster, searchText, sortField, sortDir, viewMode, minLift, minConf])

    /* ── derived stats ── */
    const totalRulesCluster = rulesAll.length
    const totalRulesGlobal = rulesGlobal.length
    const avgLift = useMemo(() => {
        const rules = activeRules
        if (!rules.length) return 0
        return rules.reduce((s, r) => s + (r.lift || 0), 0) / rules.length
    }, [activeRules])
    const maxLift = useMemo(() => Math.max(...activeRules.map(r => r.lift || 0), 0), [activeRules])
    const evalMap = useMemo(() => Object.fromEntries(armEval.map(e => [e.metric, Number(e.value)])), [armEval])
    const filterParamMap = useMemo(
        () => Object.fromEntries(armFilterParams.map(p => [p.parameter, p.value])),
        [armFilterParams]
    )
    const numberParam = (key, fallback = 0) => {
        const v = Number(filterParamMap[key])
        return Number.isFinite(v) ? v : fallback
    }
    const strictSupportPct = 100 * numberParam('strict_support')
    const strictConfPct = 100 * numberParam('strict_confidence')
    const strictLift = numberParam('strict_lift')
    const adaptiveMinCountGlobal = numberParam('adaptive_min_count_global')
    const adaptiveMinCountCluster = numberParam('adaptive_min_count_cluster')
    const adaptiveConfPct = 100 * numberParam('adaptive_confidence')
    const adaptiveLift = numberParam('adaptive_lift')
    const selectionMode = String(filterParamMap.global_selection_mode || '-')

    // unique corridors in rules
    const uniqueCorridors = useMemo(() => {
        const set = new Set()
        activeRules.forEach(r => { set.add(r.lhs); set.add(r.rhs) })
        return set.size
    }, [activeRules])

    // Scatter data: support vs confidence colored by cluster
    const scatterData = useMemo(() => filteredRules.map(r => ({
        support: r.support * 100,
        confidence: r.confidence * 100,
        lift: r.lift,
        cluster: r.cluster,
        lhs: r.lhs,
        rhs: r.rhs,
    })), [filteredRules])

    // Bar chart: rules per cluster
    const rulesPerCluster = useMemo(() => armSummary.map(s => ({
        cluster: s.cluster,
        label: s.cluster_label,
        n_rules: s.n_rules,
        avg_lift: s.avg_lift,
        max_lift: s.max_lift,
    })), [armSummary])

    // Lift distribution (histogram-like)
    const liftDistribution = useMemo(() => {
        const bins = [
            { range: '2-5', min: 2, max: 5, count: 0 },
            { range: '5-10', min: 5, max: 10, count: 0 },
            { range: '10-20', min: 10, max: 20, count: 0 },
            { range: '20-30', min: 20, max: 30, count: 0 },
            { range: '30+', min: 30, max: Infinity, count: 0 },
        ]
        activeRules.forEach(r => {
            const l = r.lift || 0
            const bin = bins.find(b => l >= b.min && l < b.max)
            if (bin) bin.count++
        })
        return bins
    }, [activeRules])

    // Top corridors by frequency in rules
    const topCorridors = useMemo(() => {
        const counts = {}
        activeRules.forEach(r => {
            counts[r.lhs] = (counts[r.lhs] || 0) + 1
            counts[r.rhs] = (counts[r.rhs] || 0) + 1
        })
        return Object.entries(counts)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10)
            .map(([name, count]) => ({ name, count }))
    }, [activeRules])

    const handleSort = (field) => {
        if (sortField === field) setSortDir(d => d === 'desc' ? 'asc' : 'desc')
        else { setSortField(field); setSortDir('desc') }
    }
    const sortIcon = (field) => {
        if (sortField !== field) return ' ↕'
        return sortDir === 'desc' ? ' ↓' : ' ↑'
    }

    if (loading) return (
        <div className="loading">
            <div className="loading-spinner" />
            <span>Memuat data ARM...</span>
        </div>
    )

    const TABS = [
        { key: 'overview', label: 'Overview', icon: '📋' },
        { key: 'rules', label: 'Tabel Rules', icon: '📊' },
        { key: 'analysis', label: 'Analisis Visual', icon: '📈' },
    ]

    return (
        <div className="arm-page">
            {/* Page header */}
            <div className="page-header">
                <div className="page-header-left">
                    <h1>Transfer Rule Mining (Trip-Based)</h1>
                    <p className="page-desc">
                        Analisis pola transfer koridor per transaksi. Rule hanya dihitung untuk pasangan koridor yang terhubung di graph halte, dengan lift lokal sebagai skor utama.
                    </p>
                </div>
                <div className="page-header-stats">
                    <StatCard label="Rules (Cluster)" value={totalRulesCluster} icon="🔗" color="#3498db" />
                    <StatCard label="Rules (Global)" value={totalRulesGlobal} icon="🌐" color="#27ae60" />
                    <StatCard label="Avg Lift Lokal" value={avgLift.toFixed(2)} icon="📈" color="#e74c3c" />
                    <StatCard label="Koridor Terlibat" value={uniqueCorridors} icon="🚌" color="#f39c12" />
                </div>
            </div>

            {/* Tab navigation */}
            <div className="tab-nav">
                {TABS.map(tab => (
                    <button
                        key={tab.key}
                        className={`tab-btn ${activeTab === tab.key ? 'active' : ''}`}
                        onClick={() => setActiveTab(tab.key)}
                    >
                        <span className="tab-icon">{tab.icon}</span>
                        {tab.label}
                    </button>
                ))}
            </div>

            {/* ═══════ TAB: OVERVIEW ═══════ */}
            {activeTab === 'overview' && (
                <>
                    {/* Summary per cluster */}
                    <Section title="Ringkasan per Cluster" subtitle="Statistik association rules berdasarkan cluster GMM">
                        <div className="arm-summary-grid">
                            {armSummary.map(s => {
                                const cs = clusterStats.find(c => Number(c.cluster) === Number(s.cluster)) || {}
                                return (
                                    <div key={s.cluster} className="arm-summary-card" style={{ '--cluster-color': CLUSTER_COLORS[s.cluster] }}>
                                        <div className="asc-header" style={{ background: CLUSTER_COLORS[s.cluster] }}>
                                            <span className="asc-cluster">C{s.cluster}</span>
                                            <span className="asc-label">{s.cluster_label}</span>
                                        </div>
                                        <div className="asc-body">
                                            <div className="asc-stat">
                                                <span>Transaksi</span>
                                                <strong>{Number(cs.n_total || 0).toLocaleString()}</strong>
                                            </div>
                                            <div className="asc-stat">
                                                <span>Cross-corridor</span>
                                                <strong>{cs.pct_cross}%</strong>
                                            </div>
                                            <div className="asc-stat">
                                                <span>Pengguna</span>
                                                <strong>{Number(cs.n_users || 0).toLocaleString()}</strong>
                                            </div>
                                            <div className="asc-divider" />
                                            <div className="asc-stat highlight">
                                                <span>Rules</span>
                                                <strong>{s.n_rules}</strong>
                                            </div>
                                            <div className="asc-stat">
                                                <span>Avg Lift Lokal</span>
                                                <strong>{Number(s.avg_lift).toFixed(2)}</strong>
                                            </div>
                                            <div className="asc-stat">
                                                <span>Avg Lift Global</span>
                                                <strong>{Number(s.avg_lift_global || 0).toFixed(1)}</strong>
                                            </div>
                                            <div className="asc-stat">
                                                <span>Avg Conf</span>
                                                <strong>{Number(s.avg_conf).toFixed(1)}%</strong>
                                            </div>
                                        </div>
                                    </div>
                                )
                            })}
                        </div>
                    </Section>

                    <Section title="Evaluasi Filter Rules" subtitle="Kualitas hasil seleksi rule setelah topology constraint + scoring lokal">
                        <div className="arm-summary-grid">
                            <div className="arm-summary-card">
                                <div className="asc-header" style={{ background: '#2563eb' }}>
                                    <span className="asc-label">Trip Coverage</span>
                                </div>
                                <div className="asc-body">
                                    <div className="asc-stat highlight">
                                        <span>Covered Trip</span>
                                        <strong>{(evalMap.trip_coverage_by_rules_pct || 0).toFixed(2)}%</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Total Connected Trip</span>
                                        <strong>{Math.round(evalMap.connected_trip_total || 0).toLocaleString()}</strong>
                                    </div>
                                </div>
                            </div>
                            <div className="arm-summary-card">
                                <div className="asc-header" style={{ background: '#059669' }}>
                                    <span className="asc-label">Compression</span>
                                </div>
                                <div className="asc-body">
                                    <div className="asc-stat highlight">
                                        <span>Rule Compression</span>
                                        <strong>{(100 * (evalMap.rule_compression_ratio || 0)).toFixed(2)}%</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Pair Candidate</span>
                                        <strong>{Math.round(evalMap.pair_candidate_total || 0).toLocaleString()}</strong>
                                    </div>
                                </div>
                            </div>
                            <div className="arm-summary-card">
                                <div className="asc-header" style={{ background: '#d97706' }}>
                                    <span className="asc-label">Support Local</span>
                                </div>
                                <div className="asc-body">
                                    <div className="asc-stat highlight">
                                        <span>Avg Support Local</span>
                                        <strong>{(evalMap.avg_support_local_pct || 0).toFixed(2)}%</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Avg Degree Adj</span>
                                        <strong>{(evalMap.avg_support_degree_adj || 0).toFixed(2)}</strong>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </Section>

                    <Section title="Parameter Seleksi Rules" subtitle="Threshold berbasis skripsi (strict) + fallback adaptif untuk jaringan transfer yang sparse">
                        <div className="arm-summary-grid">
                            <div className="arm-summary-card">
                                <div className="asc-header" style={{ background: '#7c3aed' }}>
                                    <span className="asc-label">Strict Baseline</span>
                                </div>
                                <div className="asc-body">
                                    <div className="asc-stat">
                                        <span>Min Support</span>
                                        <strong>{strictSupportPct.toFixed(2)}%</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Min Confidence</span>
                                        <strong>{strictConfPct.toFixed(2)}%</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Min Lift</span>
                                        <strong>{strictLift.toFixed(2)}</strong>
                                    </div>
                                </div>
                            </div>

                            <div className="arm-summary-card">
                                <div className="asc-header" style={{ background: '#0f766e' }}>
                                    <span className="asc-label">Adaptive Fallback</span>
                                </div>
                                <div className="asc-body">
                                    <div className="asc-stat">
                                        <span>Min Count Global</span>
                                        <strong>{Math.round(adaptiveMinCountGlobal)}</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Min Count Cluster</span>
                                        <strong>{Math.round(adaptiveMinCountCluster)}</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Min Confidence</span>
                                        <strong>{adaptiveConfPct.toFixed(2)}%</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Min Lift</span>
                                        <strong>{adaptiveLift.toFixed(2)}</strong>
                                    </div>
                                </div>
                            </div>

                            <div className="arm-summary-card">
                                <div className="asc-header" style={{ background: '#b45309' }}>
                                    <span className="asc-label">Mode Aktif (Global)</span>
                                </div>
                                <div className="asc-body">
                                    <div className="asc-stat highlight">
                                        <span>Selection Mode</span>
                                        <strong>{selectionMode}</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Rules Terpilih</span>
                                        <strong>{totalRulesGlobal}</strong>
                                    </div>
                                    <div className="asc-stat">
                                        <span>Compression</span>
                                        <strong>{(100 * (evalMap.rule_compression_ratio || 0)).toFixed(2)}%</strong>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </Section>

                    <div className="grid-2">
                        {/* Rules per cluster chart */}
                        <Section title="Jumlah Rules per Cluster">
                            <div className="chart-card">
                                <ResponsiveContainer width="100%" height={280}>
                                    <BarChart data={rulesPerCluster}>
                                        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                        <XAxis dataKey="label" tick={{ fontSize: 10 }} angle={-10} textAnchor="end" height={50} />
                                        <YAxis />
                                        <Tooltip />
                                        <Bar dataKey="n_rules" name="Rules" radius={[6, 6, 0, 0]}>
                                            {rulesPerCluster.map((e, i) => (
                                                <Cell key={i} fill={CLUSTER_COLORS[e.cluster]} />
                                            ))}
                                        </Bar>
                                    </BarChart>
                                </ResponsiveContainer>
                            </div>
                        </Section>

                        {/* Lift distribution */}
                        <Section title="Distribusi Lift">
                            <div className="chart-card">
                                <ResponsiveContainer width="100%" height={280}>
                                    <BarChart data={liftDistribution}>
                                        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                        <XAxis dataKey="range" />
                                        <YAxis />
                                        <Tooltip />
                                        <Bar dataKey="count" name="Rules" fill="#3498db" radius={[6, 6, 0, 0]} />
                                    </BarChart>
                                </ResponsiveContainer>
                            </div>
                        </Section>
                    </div>

                    {/* Top corridors */}
                    <Section title="Top 10 Koridor dalam Rules" subtitle="Koridor yang paling sering muncul dalam association rules">
                        <div className="chart-card">
                            <ResponsiveContainer width="100%" height={300}>
                                <BarChart data={topCorridors} layout="vertical" margin={{ left: 180 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                    <XAxis type="number" />
                                    <YAxis dataKey="name" type="category" tick={{ fontSize: 11 }} width={170} />
                                    <Tooltip />
                                    <Bar dataKey="count" name="Frekuensi" fill="#2ecc71" radius={[0, 6, 6, 0]} />
                                </BarChart>
                            </ResponsiveContainer>
                        </div>
                    </Section>
                </>
            )}

            {/* ═══════ TAB: RULES TABLE ═══════ */}
            {activeTab === 'rules' && (
                <>
                    {/* Filters */}
                    <div className="arm-filters-v2">
                        <div className="filter-row">
                            <div className="filter-group">
                                <label>Mode</label>
                                <div className="btn-group">
                                    <button className={`btn ${viewMode === 'cluster' ? 'active' : ''}`} onClick={() => setViewMode('cluster')}>
                                        Per Cluster ({rulesAll.length})
                                    </button>
                                    <button className={`btn ${viewMode === 'global' ? 'active' : ''}`} onClick={() => setViewMode('global')}>
                                        Global ({rulesGlobal.length})
                                    </button>
                                </div>
                            </div>

                            {viewMode === 'cluster' && (
                                <div className="filter-group">
                                    <label>Cluster</label>
                                    <select value={selectedCluster} onChange={e => setSelectedCluster(e.target.value)}>
                                        <option value="all">Semua Cluster</option>
                                        {[1, 2, 3, 4, 5].map(c => (
                                            <option key={c} value={c}>C{c}: {CLUSTER_LABELS[c]}</option>
                                        ))}
                                    </select>
                                </div>
                            )}

                            <div className="filter-group">
                                <label>Cari Koridor</label>
                                <input type="text" placeholder="Ketik nama koridor..." value={searchText} onChange={e => setSearchText(e.target.value)} />
                            </div>

                            <div className="filter-group">
                                <label>Min Lift Lokal</label>
                                <input type="number" min="0" step="1" value={minLift} onChange={e => setMinLift(Number(e.target.value) || 0)} style={{ width: 80 }} />
                            </div>

                            <div className="filter-group">
                                <label>Min Confidence</label>
                                <input type="number" min="0" max="1" step="0.05" value={minConf} onChange={e => setMinConf(Number(e.target.value) || 0)} style={{ width: 80 }} />
                            </div>
                        </div>

                        <div className="filter-status">
                            <span className="result-count">{filteredRules.length} rules ditampilkan</span>
                            {(searchText || minLift > 0 || minConf > 0 || selectedCluster !== 'all') && (
                                <button className="btn-clear" onClick={() => { setSearchText(''); setMinLift(0); setMinConf(0); setSelectedCluster('all') }}>
                                    ✕ Reset Filter
                                </button>
                            )}
                        </div>
                    </div>

                    {/* Rules table */}
                    <div className="table-wrapper">
                        <table className="data-table">
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>LHS (Antecedent)</th>
                                    <th className="td-arrow">→</th>
                                    <th>RHS (Consequent)</th>
                                    <th className="sortable" onClick={() => handleSort('support')}>Support{sortIcon('support')}</th>
                                    <th className="sortable" onClick={() => handleSort('support_local')}>Support Lokal{sortIcon('support_local')}</th>
                                    <th className="sortable" onClick={() => handleSort('confidence')}>Confidence{sortIcon('confidence')}</th>
                                    <th className="sortable" onClick={() => handleSort('lift')}>Lift{sortIcon('lift')}</th>
                                    <th className="sortable" onClick={() => handleSort('lift_global')}>Lift Global{sortIcon('lift_global')}</th>
                                    <th className="sortable" onClick={() => handleSort(viewMode === 'global' ? 'count_trips_global' : 'count_trips')}>
                                        Trips{sortIcon(viewMode === 'global' ? 'count_trips_global' : 'count_trips')}
                                    </th>
                                    <th className="sortable" onClick={() => handleSort('n_shared_stops')}>Shared Stops{sortIcon('n_shared_stops')}</th>
                                    {viewMode === 'cluster' && <th>Cluster</th>}
                                    <th>Detail</th>
                                </tr>
                            </thead>
                            <tbody>
                                {filteredRules.map((r, i) => (
                                    <tr
                                        key={i}
                                        className={selectedRule === i ? 'row-selected' : ''}
                                        onClick={() => setSelectedRule(selectedRule === i ? null : i)}
                                    >
                                        <td className="td-num">{i + 1}</td>
                                        <td className="td-corridor">{r.lhs}</td>
                                        <td className="td-arrow">→</td>
                                        <td className="td-corridor">{r.rhs}</td>
                                        <td className="td-num">{(r.support * 100).toFixed(3)}%</td>
                                        <td className="td-num">{((r.support_local || 0) * 100).toFixed(2)}%</td>
                                        <td className="td-num">
                                            <div className="conf-bar-wrap">
                                                <div className="conf-bar" style={{ width: `${r.confidence * 100}%`, background: CLUSTER_COLORS[r.cluster] || '#3498db' }} />
                                                <span>{(r.confidence * 100).toFixed(1)}%</span>
                                            </div>
                                        </td>
                                        <td className="td-num">
                                            <strong style={{ color: r.lift > 20 ? '#e74c3c' : r.lift > 10 ? '#f39c12' : '#2c3e50' }}>
                                                {r.lift?.toFixed(2)}
                                            </strong>
                                        </td>
                                        <td className="td-num">{r.lift_global?.toFixed(2)}</td>
                                        <td className="td-num">{(r.count_trips ?? r.count_trips_global ?? '-').toLocaleString()}</td>
                                        <td className="td-num">{(r.n_shared_stops ?? 0).toLocaleString()}</td>
                                        {viewMode === 'cluster' && (
                                            <td>
                                                <span className="cluster-badge" style={{ background: CLUSTER_COLORS[r.cluster] }}>
                                                    C{r.cluster}
                                                </span>
                                            </td>
                                        )}
                                        <td>
                                            <button className="btn-detail" onClick={(e) => { e.stopPropagation(); setSelectedRule(selectedRule === i ? null : i) }}>
                                                {selectedRule === i ? '▲' : '▼'}
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>

                    {/* Expanded rule detail */}
                    {selectedRule !== null && filteredRules[selectedRule] && (
                        <div className="rule-detail-panel">
                            <div className="rdp-header">
                                <h4>Detail Rule #{selectedRule + 1}</h4>
                                <button className="btn-close" onClick={() => setSelectedRule(null)}>✕</button>
                            </div>
                            <div className="rdp-body">
                                <div className="rdp-rule-visual">
                                    <div className="rdp-lhs">{filteredRules[selectedRule].lhs}</div>
                                    <div className="rdp-arrow">→</div>
                                    <div className="rdp-rhs">{filteredRules[selectedRule].rhs}</div>
                                </div>
                                <div className="rdp-metrics">
                                    <div className="rdp-metric">
                                        <span className="rdp-metric-label">Support</span>
                                        <span className="rdp-metric-val">{(filteredRules[selectedRule].support * 100).toFixed(4)}%</span>
                                        <span className="rdp-metric-desc">Proporsi trip transfer terhubung yang memuat LHS {'=>'} RHS</span>
                                    </div>
                                    <div className="rdp-metric">
                                        <span className="rdp-metric-label">Confidence</span>
                                        <span className="rdp-metric-val">{(filteredRules[selectedRule].confidence * 100).toFixed(2)}%</span>
                                        <span className="rdp-metric-desc">P(RHS | LHS) pada transaksi transfer</span>
                                    </div>
                                    <div className="rdp-metric">
                                        <span className="rdp-metric-label">Support Lokal</span>
                                        <span className="rdp-metric-val">{((filteredRules[selectedRule].support_local || 0) * 100).toFixed(2)}%</span>
                                        <span className="rdp-metric-desc">Porsi trip LHS yang menuju RHS (tergantung konektivitas koridor LHS)</span>
                                    </div>
                                    <div className="rdp-metric">
                                        <span className="rdp-metric-label">Lift Lokal</span>
                                        <span className="rdp-metric-val">{filteredRules[selectedRule].lift?.toFixed(3)}</span>
                                        <span className="rdp-metric-desc">Rasio terhadap baseline tetangga koridor LHS ({'>'}1 = lebih kuat dari ekspektasi lokal)</span>
                                    </div>
                                    <div className="rdp-metric">
                                        <span className="rdp-metric-label">Trips</span>
                                        <span className="rdp-metric-val">{(filteredRules[selectedRule].count_trips ?? filteredRules[selectedRule].count_trips_global ?? '-').toLocaleString()}</span>
                                        <span className="rdp-metric-desc">Jumlah transaksi transfer LHS {'=>'} RHS</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    )}
                </>
            )}

            {/* ═══════ TAB: ANALYSIS ═══════ */}
            {activeTab === 'analysis' && (
                <>
                    <Section title="Support vs Confidence" subtitle="Visualisasi kualitas rules — setiap titik adalah satu rule, ukuran = lift">
                        <div className="chart-card">
                            <ResponsiveContainer width="100%" height={400}>
                                <ScatterChart margin={{ top: 10, right: 30, left: 20, bottom: 20 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                    <XAxis dataKey="support" name="Support (%)" label={{ value: 'Support (%)', position: 'insideBottom', offset: -10 }} />
                                    <YAxis dataKey="confidence" name="Confidence (%)" label={{ value: 'Confidence (%)', angle: -90, position: 'insideLeft' }} />
                                    <ZAxis dataKey="lift" range={[60, 400]} name="Lift" />
                                    <Tooltip content={({ active, payload }) => {
                                        if (!active || !payload?.length) return null
                                        const d = payload[0]?.payload
                                        return (
                                            <div className="custom-tooltip">
                                                <div className="tooltip-label">{d?.lhs} → {d?.rhs}</div>
                                                <div className="tooltip-row"><span className="tooltip-name">Support:</span> <strong>{d?.support?.toFixed(3)}%</strong></div>
                                                <div className="tooltip-row"><span className="tooltip-name">Confidence:</span> <strong>{d?.confidence?.toFixed(1)}%</strong></div>
                                                <div className="tooltip-row"><span className="tooltip-name">Lift:</span> <strong>{d?.lift?.toFixed(2)}</strong></div>
                                            </div>
                                        )
                                    }} />
                                    {viewMode === 'cluster'
                                        ? [1, 2, 3, 4, 5].map(cl => (
                                            <Scatter
                                                key={cl}
                                                name={`C${cl}: ${CLUSTER_LABELS[cl]}`}
                                                data={scatterData.filter(d => d.cluster === cl)}
                                                fill={CLUSTER_COLORS[cl]}
                                                fillOpacity={0.7}
                                            />
                                        ))
                                        : <Scatter name="Global" data={scatterData} fill="#3498db" fillOpacity={0.7} />
                                    }
                                    <Legend />
                                </ScatterChart>
                            </ResponsiveContainer>
                        </div>
                    </Section>

                    <Section title="Perbandingan Avg Lift per Cluster" subtitle="Rata-rata dan maksimum lift per cluster — cluster dengan lift tinggi memiliki pola yang lebih kuat">
                        <div className="chart-card">
                            <ResponsiveContainer width="100%" height={300}>
                                <BarChart data={rulesPerCluster}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                    <XAxis dataKey="label" tick={{ fontSize: 10 }} />
                                    <YAxis />
                                    <Tooltip />
                                    <Legend />
                                    <Bar dataKey="avg_lift" name="Avg Lift" fill="#3498db" radius={[4, 4, 0, 0]} />
                                    <Bar dataKey="avg_lift_global" name="Avg Lift Global" fill="#e74c3c" radius={[4, 4, 0, 0]} />
                                </BarChart>
                            </ResponsiveContainer>
                        </div>
                    </Section>

                    {/* Methodology Note */}
                    <Section title="Metodologi">
                        <div className="methodology-card">
                            <div className="method-item">
                                <div className="method-icon">1️⃣</div>
                                <div>
                                    <strong>Basket Construction</strong>
                                    <p>Setiap transaksi cross-corridor diperlakukan sebagai transfer terarah: {`{corridorName -> tapOut_corridorName}`}. Support dihitung pada basis transaksi.</p>
                                </div>
                            </div>
                            <div className="method-item">
                                <div className="method-icon">2️⃣</div>
                                <div>
                                    <strong>Topology Constraint</strong>
                                    <p>Rule hanya dianggap valid jika kedua koridor berbagi halte (diambil dari data_halte.csv), sehingga pasangan non-terhubung otomatis dieliminasi.</p>
                                </div>
                            </div>
                            <div className="method-item">
                                <div className="method-icon">3️⃣</div>
                                <div>
                                    <strong>Dual Lift Scoring</strong>
                                    <p>Lift global tetap dihitung, namun ranking utama memakai lift lokal (baseline tetangga koridor asal) agar tidak bias pada network sparse.</p>
                                </div>
                            </div>
                            <div className="method-item">
                                <div className="method-icon">4️⃣</div>
                                <div>
                                    <strong>Cluster Integration</strong>
                                    <p>Global rules kemudian di-rescore dalam setiap cluster GMM untuk melihat variasi kekuatan pola antar segmen penumpang.</p>
                                </div>
                            </div>
                        </div>
                    </Section>
                </>
            )}
        </div>
    )
}
