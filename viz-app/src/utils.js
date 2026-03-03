import Papa from 'papaparse'

export async function loadCSV(path) {
    const res = await fetch(path)
    const text = await res.text()
    return new Promise((resolve) => {
        Papa.parse(text, {
            header: true,
            skipEmptyLines: true,
            dynamicTyping: true,
            complete: (results) => resolve(results.data)
        })
    })
}

/**
 * Normalisasi nama koridor: hapus suffix " via ..." agar konsisten dengan
 * output ARM yang sudah dinormalisasi di R (01_load_data.R).
 * Contoh: "Cililitan - Condet via Kayu Manis" → "Cililitan - Condet"
 */
export function normalizeCorridor(name) {
    if (!name) return name
    return String(name).replace(/\s+via\s+.*$/i, '').trim()
}

/**
 * Terapkan normalizeCorridor pada field corridorName di array of objects.
 * Digunakan saat loading halte.csv agar cocok dengan ARM rules.
 */
export function normalizeCorridorField(rows, field = 'corridorName') {
    return rows.map((r) => ({ ...r, [field]: normalizeCorridor(r[field]) }))
}

// Keep rules where support/confidence are <= maxRatio (default 0.8 / 80%).
// Supports both ratio format (0..1) and percent format (0..100).
export function filterRulesByMaxSupportConfidence(rows, maxRatio = 0.8) {
    const toRatio = (v) => {
        const n = Number(v)
        if (!Number.isFinite(n)) return null
        return n > 1 ? n / 100 : n
    }
    return rows.filter((r) => {
        const support = toRatio(r.support)
        const confidence = toRatio(r.confidence)
        const supportOk = support === null || support <= maxRatio
        const confidenceOk = confidence === null || confidence <= maxRatio
        return supportOk && confidenceOk
    })
}

// Cluster colors used throughout the app
export const CLUSTER_COLORS = {
    1: '#e74c3c', // Commuter Sore - red
    2: '#f39c12', // Penumpang Intensif - orange
    3: '#2ecc71', // Commuter Pagi - green
    4: '#3498db', // Commuter Pagi Dini - blue
    5: '#9b59b6', // Penumpang Kasual - purple
}

export const CLUSTER_LABELS = {
    1: 'Commuter Sore',
    2: 'Penumpang Intensif',
    3: 'Commuter Pagi',
    4: 'Commuter Pagi Dini',
    5: 'Penumpang Kasual',
}
