
import { useState, useEffect, useMemo } from 'react'
import {
    BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
    RadarChart, Radar, PolarGrid, PolarAngleAxis, PolarRadiusAxis,
    ResponsiveContainer, Cell, PieChart, Pie,
    ScatterChart, Scatter, ZAxis, ComposedChart, Area, Line
} from 'recharts'
import { loadCSV, CLUSTER_COLORS, CLUSTER_LABELS } from '../utils'

const FALLBACK_COLORS = [
    '#e74c3c', '#f39c12', '#2ecc71', '#3498db', '#9b59b6', '#1abc9c',
    '#e67e22', '#16a085', '#c0392b', '#8e44ad', '#2c3e50', '#27ae60'
]

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

function CustomTooltip({ active, payload, label, formatter }) {
    if (!active || !payload?.length) return null
    return (
        <div className="custom-tooltip">
            <div className="tooltip-label">{label}</div>
            {payload.map((p, i) => (
                <div key={i} className="tooltip-row">
                    <span className="tooltip-dot" style={{ background: p.color || p.stroke }} />
                    <span className="tooltip-name">{p.name}:</span>
                    <span className="tooltip-val">{formatter ? formatter(p.value) : p.value?.toLocaleString()}</span>
                </div>
            ))}
        </div>
    )
}

function buildClusterEdaNotes(profile) {
    const notes = []
    const hour = Number(profile.mean_tapIn_hour) || 0
    const duration = Number(profile.mean_duration_min) || 0
    const weekend = Number(profile.pct_weekend) || 0
    const trips = Number(profile.mean_n_trips) || 0
    const days = Number(profile.mean_n_days_month) || 0

    let timeBand = 'siang'
    if (hour < 7) timeBand = 'pagi dini'
    else if (hour < 10) timeBand = 'pagi'
    else if (hour >= 16) timeBand = 'sore/malam'
    notes.push(`Aktivitas dominan di ${timeBand} (jam rata-rata ${hour.toFixed(2)}).`)

    const intensity = trips >= 3 ? 'tinggi' : trips >= 2 ? 'sedang' : 'rendah'
    notes.push(`Intensitas perjalanan ${intensity}: ${trips.toFixed(2)} trip per hari, dengan ${days.toFixed(2)} hari aktif per bulan.`)

    const weekendPattern = weekend >= 50 ? 'dominan akhir pekan' : weekend <= 15 ? 'dominan hari kerja' : 'campuran weekday-weekend'
    notes.push(`Pola waktu penggunaan ${weekendPattern} (${weekend.toFixed(2)}% weekend).`)

    const durBand = duration >= 90 ? 'panjang' : duration <= 50 ? 'pendek' : 'menengah'
    notes.push(`Durasi perjalanan relatif ${durBand} (${duration.toFixed(2)} menit).`)

    return notes
}

function normalizeBicBestRows(rows) {
    const normalized = rows.map((row) => ({
        ...row,
        displayModelType: row.ModelType,
        displayBIC: Number(row.BIC),
        displayNParam: Number(row.nParam),
        displayLogLik: Number(row.LogLik),
    }))

    return normalized.map((row, index) => ({
        ...row,
        displayBICDelta: index === 0 ? null : row.displayBIC - normalized[index - 1].displayBIC,
    }))
}

export default function GMMPage() {
    const [profiles, setProfiles] = useState([])
    const [bicAll, setBicAll] = useState([])
    const [bicBest, setBicBest] = useState([])
    const [evaluation, setEvaluation] = useState([])
    const [gmmParams, setGmmParams] = useState([])
    const [modelSelection, setModelSelection] = useState([])
    const [activeTab, setActiveTab] = useState('overview')
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        Promise.all([
            loadCSV('/data/cluster_profiles.csv'),
            loadCSV('/data/bic_all.csv'),
            loadCSV('/data/bic_best.csv'),
            loadCSV('/data/evaluation.csv'),
            loadCSV('/data/gmm_parameters.csv'),
            loadCSV('/data/gmm_model_selection.csv'),
        ]).then(([p, ba, bb, ev, gp, ms]) => {
            setProfiles(p)
            setBicAll(ba)
            setBicBest(bb)
            setEvaluation(ev)
            setGmmParams(gp)
            setModelSelection(ms)
            setLoading(false)
        })
    }, [])

    const selectedMeta = useMemo(() => modelSelection?.[0] || {}, [modelSelection])

    const bicBestDisplay = useMemo(() => normalizeBicBestRows(bicBest), [bicBest])

    const bestBicRow = useMemo(() => {
        if (!bicBestDisplay.length) return {}
        return [...bicBestDisplay].sort((a, b) => Number(b.displayBIC) - Number(a.displayBIC))[0] || {}
    }, [bicBestDisplay])

    const selectedK = useMemo(() => {
        const k = Number(selectedMeta.selected_k)
        if (Number.isFinite(k) && k > 0) return k
        if (!evaluation.length) return null
        const fallback = [...evaluation].sort((a, b) => Number(b.BIC_normalized) - Number(a.BIC_normalized))[0]
        return Number(fallback?.K) || null
    }, [selectedMeta, evaluation])

    const selectedModelType = useMemo(() => {
        if (selectedMeta?.selected_model) return String(selectedMeta.selected_model)
        const row = evaluation.find(e => Number(e.K) === Number(selectedK))
        return row?.Model || '-'
    }, [selectedMeta, evaluation, selectedK])

    const bestEval = useMemo(() => {
        if (!evaluation.length) return {}
        const bySelectedK = evaluation.find(e => Number(e.K) === Number(selectedK))
        if (bySelectedK) return bySelectedK
        return [...evaluation].sort((a, b) => Number(b.BIC_normalized) - Number(a.BIC_normalized))[0] || {}
    }, [evaluation, selectedK])

    const totalObs = useMemo(
        () => profiles.reduce((s, p) => s + (Number(p.n_obs) || 0), 0),
        [profiles]
    )

    const profileLabelMap = useMemo(() => {
        const map = {}
        profiles.forEach(p => { map[Number(p.cluster)] = p.label })
        return map
    }, [profiles])

    const getClusterColor = (clusterId) => {
        const id = Number(clusterId)
        return CLUSTER_COLORS[id] || FALLBACK_COLORS[(Math.max(id, 1) - 1) % FALLBACK_COLORS.length]
    }

    const getClusterLabel = (clusterId) => {
        const id = Number(clusterId)
        return profileLabelMap[id] || CLUSTER_LABELS[id] || `Cluster ${id}`
    }

    const pieData = useMemo(() => profiles.map(p => ({
        name: `C${p.cluster}: ${p.label}`,
        value: Number(p.n_obs) || 0,
        cluster: Number(p.cluster),
        pct: Number(p.pct_obs) || 0,
    })), [profiles])

    const radarFeatures = ['z_tapIn_hour', 'z_duration_minutes', 'z_n_trips', 'z_n_days_month', 'is_weekend', 'is_commuter']
    const radarLabels = {
        z_tapIn_hour: 'Jam Tap-In',
        z_duration_minutes: 'Durasi',
        z_n_trips: 'Jumlah Trip',
        z_n_days_month: 'Hari Aktif',
        is_weekend: 'Weekend',
        is_commuter: 'Commuter',
    }
    const radarData = useMemo(() => radarFeatures.map(feat => {
        const row = { feature: radarLabels[feat] }
        gmmParams.forEach(p => {
            row[`Cluster ${p.cluster}`] = Number(p[feat]) || 0
        })
        return row
    }), [gmmParams])

    const profileBarData = useMemo(() => profiles.map(p => ({
        name: p.label,
        cluster: Number(p.cluster),
        n_obs: Number(p.n_obs) || 0,
        pct: Number(p.pct_obs) || 0,
    })), [profiles])

    const bicLineData = useMemo(() => bicBestDisplay.map(b => ({
        K: Number(b.K),
        BIC: Number(b.displayBIC),
        Model: b.displayModelType,
        delta: b.displayBICDelta,
    })), [bicBestDisplay])

    const heatmapData = useMemo(() => {
        const features = ['mean_tapIn_hour', 'mean_duration_min', 'pct_weekend', 'mean_n_trips', 'mean_n_days_month']
        const labels = {
            mean_tapIn_hour: 'Jam Tap-In',
            mean_duration_min: 'Durasi (menit)',
            pct_weekend: '% Weekend',
            mean_n_trips: 'Rata-rata Trip',
            mean_n_days_month: 'Hari/Bulan',
        }
        return features.map(f => {
            const row = { feature: labels[f] }
            profiles.forEach(p => {
                row[`C${p.cluster}`] = Number(p[f]) || 0
            })
            return row
        })
    }, [profiles])

    const scatterData = useMemo(() => profiles.map(p => ({
        x: Number(p.mean_tapIn_hour) || 0,
        y: Number(p.mean_duration_min) || 0,
        z: Number(p.n_obs) || 0,
        cluster: Number(p.cluster),
        label: p.label,
    })), [profiles])

    if (loading) return (
        <div className="loading">
            <div className="loading-spinner" />
            <span>Memuat data GMM...</span>
        </div>
    )

    const tabs = [
        { key: 'overview', label: 'Overview', icon: 'OVR' },
        { key: 'bic', label: 'BIC & Model Selection', icon: 'BIC' },
        { key: 'clusters', label: 'Profil Cluster', icon: 'CLU' },
        { key: 'comparison', label: 'Perbandingan', icon: 'CMP' },
        { key: 'parameters', label: 'Parameter GMM', icon: 'PAR' },
    ]

    return (
        <div className="gmm-page">
            <div className="page-header">
                <div className="page-header-left">
                    <h1>Gaussian Mixture Model (GMM)</h1>
                    <p className="page-desc">
                        Clustering penumpang TransJakarta menggunakan GMM dengan {profiles.length} cluster
                        berdasarkan fitur perilaku perjalanan.
                    </p>
                </div>
                <div className="page-header-stats">
                    <StatCard label="Total Observasi" value={totalObs.toLocaleString()} icon="OBS" color="#3498db" />
                    <StatCard label="Jumlah Cluster" value={profiles.length} icon="CLU" color="#e74c3c" />
                    <StatCard label="Best BIC" value={bestBicRow.displayModelType || '-'} sub={bestBicRow.K ? `K=${bestBicRow.K}` : '-'} icon="MOD" color="#27ae60" />
                    <StatCard label="Cluster Balance" value={bestEval.Cluster_balance?.toFixed(4) || '-'} icon="BAL" color="#9b59b6" />
                </div>
            </div>

            <div className="tab-nav">
                {tabs.map(tab => (
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

            {activeTab === 'overview' && (
                <>
                    <Section title="Distribusi Cluster" subtitle="Proporsi observasi per cluster penumpang">
                        <div className="grid-2">
                            <div className="chart-card">
                                <div className="chart-card-title">Distribusi Observasi</div>
                                <ResponsiveContainer width="100%" height={320}>
                                    <BarChart data={profileBarData} margin={{ top: 10, right: 30, left: 0, bottom: 5 }}>
                                        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                        <XAxis dataKey="name" tick={{ fontSize: 11 }} angle={-15} textAnchor="end" height={60} />
                                        <YAxis tickFormatter={v => v.toLocaleString()} />
                                        <Tooltip content={<CustomTooltip />} />
                                        <Bar dataKey="n_obs" name="Observasi" radius={[6, 6, 0, 0]}>
                                            {profileBarData.map((e, i) => (
                                                <Cell key={i} fill={getClusterColor(e.cluster)} />
                                            ))}
                                        </Bar>
                                    </BarChart>
                                </ResponsiveContainer>
                            </div>

                            <div className="chart-card">
                                <div className="chart-card-title">Proporsi (%)</div>
                                <ResponsiveContainer width="100%" height={320}>
                                    <PieChart>
                                        <Pie
                                            data={pieData}
                                            dataKey="value"
                                            nameKey="name"
                                            cx="50%"
                                            cy="50%"
                                            outerRadius={110}
                                            innerRadius={55}
                                            paddingAngle={2}
                                            label={({ pct }) => `${pct}%`}
                                            labelLine={{ strokeWidth: 1 }}
                                        >
                                            {pieData.map((e, i) => (
                                                <Cell key={i} fill={getClusterColor(e.cluster)} stroke="#fff" strokeWidth={2} />
                                            ))}
                                        </Pie>
                                        <Tooltip formatter={(v) => v.toLocaleString()} />
                                        <Legend />
                                    </PieChart>
                                </ResponsiveContainer>
                            </div>
                        </div>
                    </Section>

                    <Section title="Ringkasan Cluster" subtitle="Karakteristik utama setiap cluster penumpang">
                        <div className="cluster-overview-grid">
                            {profiles.map(p => (
                                <div key={p.cluster} className="cluster-overview-card" style={{ '--cluster-color': getClusterColor(p.cluster) }}>
                                    <div className="coc-header">
                                        <span className="coc-badge" style={{ background: getClusterColor(p.cluster) }}>C{p.cluster}</span>
                                        <span className="coc-label">{p.label}</span>
                                    </div>
                                    <div className="coc-stats">
                                        <div className="coc-stat">
                                            <span className="coc-stat-val">{Number(p.n_obs).toLocaleString()}</span>
                                            <span className="coc-stat-label">observasi ({p.pct_obs}%)</span>
                                        </div>
                                        <div className="coc-stat">
                                            <span className="coc-stat-val">{Number(p.mean_tapIn_hour).toFixed(1)}h</span>
                                            <span className="coc-stat-label">avg tap-in</span>
                                        </div>
                                        <div className="coc-stat">
                                            <span className="coc-stat-val">{Number(p.mean_duration_min).toFixed(0)}m</span>
                                            <span className="coc-stat-label">avg durasi</span>
                                        </div>
                                        <div className="coc-stat">
                                            <span className="coc-stat-val">{Number(p.mean_n_trips).toFixed(2)}</span>
                                            <span className="coc-stat-label">trip per hari</span>
                                        </div>
                                    </div>
                                    <div className="coc-corridor">
                                        <span className="coc-corridor-label">Top Koridor:</span>
                                        <span className="coc-corridor-name">{p.top_corridor}</span>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </Section>

                    <Section title="Model Evaluation" subtitle="Perbandingan evaluasi model GMM untuk berbagai K kandidat">
                        <div className="eval-grid">
                            {evaluation.map(ev => (
                                <div key={ev.K} className={`eval-card-v2 ${Number(ev.K) === Number(selectedK) ? 'chosen' : ''}`}>
                                    <div className="eval-card-header">
                                        <span className="eval-k-badge">K = {ev.K}</span>
                                        {Number(ev.K) === Number(selectedK) && <span className="eval-chosen-badge">Terpilih</span>}
                                    </div>
                                    <div className="eval-card-body">
                                        <div className="eval-row"><span>Model</span><strong>{ev.Model}</strong></div>
                                        <div className="eval-row"><span>Log-Likelihood</span><strong>{Number(ev.LogLikelihood).toLocaleString()}</strong></div>
                                        <div className="eval-row"><span>BIC (normalized)</span><strong>{Number(ev.BIC_normalized).toFixed(4)}</strong></div>
                                        <div className="eval-row"><span>Parameters</span><strong>{ev.Num_params}</strong></div>
                                        <div className="eval-row"><span>Cluster Balance</span><strong>{Number(ev.Cluster_balance).toFixed(4)}</strong></div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </Section>
                </>
            )}

            {activeTab === 'bic' && (
                <>
                    <Section title="BIC per Jumlah Cluster (K)" subtitle="Bayesian Information Criterion - pada mclust, semakin tinggi (kurang negatif) semakin baik">
                        <div className="chart-card">
                            <div className="chart-card-title">BIC dari 04_bic_best_per_k.csv</div>
                            <ResponsiveContainer width="100%" height={380}>
                                <ComposedChart data={bicLineData} margin={{ top: 10, right: 40, left: 20, bottom: 10 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                    <XAxis dataKey="K" label={{ value: 'K (jumlah cluster)', position: 'insideBottom', offset: -5 }} />
                                    <YAxis yAxisId="bic" label={{ value: 'BIC', angle: -90, position: 'insideLeft' }} tickFormatter={v => (v / 1000).toFixed(0) + 'K'} />
                                    <Tooltip content={({ active, payload, label }) => {
                                        if (!active || !payload?.length) return null
                                        const d = payload[0]?.payload
                                        return (
                                            <div className="custom-tooltip">
                                                <div className="tooltip-label">K = {label}</div>
                                                <div className="tooltip-row"><span className="tooltip-name">Model:</span> <strong>{d?.Model}</strong></div>
                                                <div className="tooltip-row"><span className="tooltip-name">BIC:</span> <strong>{Number(d?.BIC).toLocaleString()}</strong></div>
                                                {Number.isFinite(d?.delta) && <div className="tooltip-row"><span className="tooltip-name">Delta BIC:</span> <strong>{Number(d.delta).toLocaleString()}</strong></div>}
                                            </div>
                                        )
                                    }} />
                                    <Legend />
                                    <Area yAxisId="bic" type="monotone" dataKey="BIC" fill="#3498db" fillOpacity={0.1} stroke="none" />
                                    <Line yAxisId="bic" type="monotone" dataKey="BIC" stroke="#3498db" strokeWidth={3} dot={{ r: 6, fill: '#fff', stroke: '#3498db', strokeWidth: 2 }} activeDot={{ r: 8 }} name="BIC" />
                                </ComposedChart>
                            </ResponsiveContainer>
                        </div>
                    </Section>

                    <Section title="BIC Terbaik per K" subtitle="Diambil langsung dari 04_bic_best_per_k.csv">
                        <div className="table-wrapper" style={{ marginTop: 16 }}>
                            <table className="data-table">
                                <thead>
                                    <tr>
                                        <th>K</th>
                                        <th>Model Type</th>
                                        <th>BIC</th>
                                        <th>Parameters</th>
                                        <th>Log-Likelihood</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {bicBestDisplay.map((b, i) => (
                                        <tr key={i} className={Number(b.K) === Number(bestBicRow.K) && String(b.displayModelType) === String(bestBicRow.displayModelType) ? 'row-highlight' : ''}>
                                            <td className="td-center">{b.K}</td>
                                            <td><code>{b.displayModelType}</code></td>
                                            <td className="td-num">{Number(b.displayBIC).toLocaleString()}</td>
                                            <td className="td-center">{Number.isFinite(b.displayNParam) ? b.displayNParam : 'NA'}</td>
                                            <td className="td-num">{Number.isFinite(b.displayLogLik) ? Number(b.displayLogLik).toLocaleString() : 'NA'}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </Section>
                </>
            )}

            {activeTab === 'clusters' && (
                <Section title="Profil Detail Cluster" subtitle="Kartu detail cluster plus keterangan EDA ringkas">
                    <div className="cluster-detail-grid">
                        {profiles.map(p => (
                            <div key={p.cluster} className="cluster-detail-card" style={{ '--cluster-color': getClusterColor(p.cluster) }}>
                                <div className="cdc-header" style={{ background: getClusterColor(p.cluster) }}>
                                    <div className="cdc-cluster-num">Cluster {p.cluster}</div>
                                    <div className="cdc-cluster-label">{p.label}</div>
                                    <div className="cdc-cluster-count">{Number(p.n_obs).toLocaleString()} observasi ({p.pct_obs}%)</div>
                                </div>
                                    <div className="cdc-body">
                                        <div className="cdc-section">
                                            <div className="cdc-section-title">Waktu Perjalanan</div>
                                        <div className="cdc-row"><span>Jam Tap-In</span><strong>Rata-rata {Number(p.mean_tapIn_hour).toFixed(2)} jam</strong></div>
                                        <div className="cdc-row"><span>Durasi</span><strong>Rata-rata {Number(p.mean_duration_min).toFixed(2)} menit</strong></div>
                                        </div>
                                        <div className="cdc-section">
                                            <div className="cdc-section-title">Intensitas</div>
                                        <div className="cdc-row"><span>Trip per hari</span><strong>{Number(p.mean_n_trips).toFixed(2)}</strong></div>
                                        <div className="cdc-row"><span>Hari aktif/bulan</span><strong>{Number(p.mean_n_days_month).toFixed(2)}</strong></div>
                                        </div>
                                    <div className="cdc-section">
                                        <div className="cdc-section-title">Komposisi</div>
                                        <div className="cdc-row"><span>Weekend</span><strong>{Number(p.pct_weekend).toFixed(2)}%</strong></div>
                                    </div>
                                    <div className="cdc-section">
                                        <div className="cdc-section-title">Top Koridor</div>
                                        <div className="cdc-corridor">{p.top_corridor}</div>
                                    </div>
                                    <div className="cdc-section">
                                        <div className="cdc-section-title">Keterangan EDA</div>
                                        <ul className="cdc-eda-list">
                                            {buildClusterEdaNotes(p).map((note, idx) => (
                                                <li key={idx}>{note}</li>
                                            ))}
                                        </ul>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </Section>
            )}

            {activeTab === 'comparison' && (
                <>
                    <Section title="Radar Chart: Z-Score Features" subtitle="Perbandingan z-score fitur antar cluster">
                        <div className="chart-card">
                            <ResponsiveContainer width="100%" height={450}>
                                <RadarChart data={radarData} cx="50%" cy="50%" outerRadius="75%">
                                    <PolarGrid stroke="#e0e0e0" />
                                    <PolarAngleAxis dataKey="feature" tick={{ fontSize: 12, fill: '#555' }} />
                                    <PolarRadiusAxis tick={{ fontSize: 10 }} />
                                    {gmmParams.map(p => (
                                        <Radar
                                            key={p.cluster}
                                            name={`C${p.cluster}: ${getClusterLabel(p.cluster)}`}
                                            dataKey={`Cluster ${p.cluster}`}
                                            stroke={getClusterColor(p.cluster)}
                                            fill={getClusterColor(p.cluster)}
                                            fillOpacity={0.12}
                                            strokeWidth={2}
                                        />
                                    ))}
                                    <Legend wrapperStyle={{ paddingTop: 20 }} />
                                    <Tooltip />
                                </RadarChart>
                            </ResponsiveContainer>
                        </div>
                    </Section>

                    <Section title="Scatter: Jam Tap-In vs Durasi" subtitle="Posisi setiap cluster berdasarkan rata-rata jam tap-in dan durasi perjalanan">
                        <div className="chart-card">
                            <ResponsiveContainer width="100%" height={400}>
                                <ScatterChart margin={{ top: 10, right: 30, left: 20, bottom: 20 }}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                    <XAxis dataKey="x" name="Jam Tap-In" label={{ value: 'Rata-rata Jam Tap-In', position: 'insideBottom', offset: -10 }} />
                                    <YAxis dataKey="y" name="Durasi (menit)" label={{ value: 'Rata-rata Durasi (menit)', angle: -90, position: 'insideLeft' }} />
                                    <ZAxis dataKey="z" range={[200, 1500]} name="Observasi" />
                                    <Tooltip />
                                    {scatterData.map(d => (
                                        <Scatter key={d.cluster} name={`C${d.cluster}: ${d.label}`} data={[d]} fill={getClusterColor(d.cluster)} stroke={getClusterColor(d.cluster)} />
                                    ))}
                                    <Legend />
                                </ScatterChart>
                            </ResponsiveContainer>
                        </div>
                    </Section>

                    <Section title="Perbandingan Fitur Antar Cluster" subtitle="Tabel perbandingan nilai rata-rata fitur">
                        <div className="table-wrapper">
                            <table className="data-table comparison-table">
                                <thead>
                                    <tr>
                                        <th>Fitur</th>
                                        {profiles.map(p => (
                                            <th key={p.cluster} style={{ color: getClusterColor(p.cluster) }}>
                                                C{p.cluster}: {p.label}
                                            </th>
                                        ))}
                                    </tr>
                                </thead>
                                <tbody>
                                    {heatmapData.map((row, i) => {
                                        const vals = profiles.map(p => row[`C${p.cluster}`])
                                        const max = Math.max(...vals)
                                        const min = Math.min(...vals)
                                        return (
                                            <tr key={i}>
                                                <td className="td-feature">{row.feature}</td>
                                                {profiles.map(p => {
                                                    const val = row[`C${p.cluster}`]
                                                    const isMax = val === max
                                                    const isMin = val === min
                                                    return (
                                                        <td key={p.cluster} className={`td-num ${isMax ? 'val-max' : ''} ${isMin ? 'val-min' : ''}`}>
                                                            {typeof val === 'number' ? val.toFixed(2) : val}
                                                        </td>
                                                    )
                                                })}
                                            </tr>
                                        )
                                    })}
                                </tbody>
                            </table>
                        </div>
                    </Section>
                </>
            )}

            {activeTab === 'parameters' && (
                <>
                    <Section title="GMM Parameters (Z-Score)" subtitle="Parameter mean setiap komponen Gaussian">
                        <div className="table-wrapper">
                            <table className="data-table">
                                <thead>
                                    <tr>
                                        <th>Cluster</th>
                                        <th>Proportion</th>
                                        <th>z Jam Tap-In</th>
                                        <th>z Durasi</th>
                                        <th>z Trips</th>
                                        <th>z Hari</th>
                                        <th>Weekend</th>
                                        <th>Commuter</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {gmmParams.map(p => (
                                        <tr key={p.cluster}>
                                            <td>
                                                <span className="cluster-badge" style={{ background: getClusterColor(p.cluster) }}>
                                                    C{p.cluster}: {getClusterLabel(p.cluster)}
                                                </span>
                                            </td>
                                            <td className="td-num">{(Number(p.proportion) * 100).toFixed(2)}%</td>
                                            <td className="td-num">{Number(p.z_tapIn_hour).toFixed(4)}</td>
                                            <td className="td-num">{Number(p.z_duration_minutes).toFixed(4)}</td>
                                            <td className="td-num">{Number(p.z_n_trips).toFixed(4)}</td>
                                            <td className="td-num">{Number(p.z_n_days_month).toFixed(4)}</td>
                                            <td className="td-num">{(Number(p.is_weekend) * 100).toFixed(2)}%</td>
                                            <td className="td-num">{(Number(p.is_commuter) * 100).toFixed(2)}%</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </Section>

                    <Section title="Interpretasi" subtitle="Interpretasi ringkas berbasis parameter dan profil cluster">
                        <div className="interpretation-grid">
                            {profiles.map(p => {
                                const param = gmmParams.find(g => Number(g.cluster) === Number(p.cluster)) || {}
                                const traits = []
                                if (Number(param.z_tapIn_hour) > 0.5) traits.push('Tap-in sore/malam')
                                else if (Number(param.z_tapIn_hour) < -0.5) traits.push('Tap-in pagi')
                                if (Number(param.z_duration_minutes) > 0.5) traits.push('Durasi panjang')
                                else if (Number(param.z_duration_minutes) < -0.5) traits.push('Durasi pendek')
                                if (Number(param.z_n_trips) > 0.5) traits.push('Banyak trip')
                                else if (Number(param.z_n_trips) < -0.5) traits.push('Sedikit trip')
                                if (Number(param.z_n_days_month) > 0.5) traits.push('Aktif banyak hari')
                                else if (Number(param.z_n_days_month) < -0.5) traits.push('Jarang travel')
                                if (Number(param.is_weekend) > 0.3) traits.push('Banyak weekend')

                                return (
                                    <div key={p.cluster} className="interp-card" style={{ borderLeft: `4px solid ${getClusterColor(p.cluster)}` }}>
                                        <div className="interp-header" style={{ color: getClusterColor(p.cluster) }}>
                                            C{p.cluster}: {p.label}
                                        </div>
                                        <div className="interp-proportion">
                                            {(Number(param.proportion) * 100).toFixed(1)}% dari total penumpang
                                        </div>
                                        <div className="interp-traits">
                                            {traits.map((t, i) => (
                                                <span key={i} className="trait-tag">{t}</span>
                                            ))}
                                        </div>
                                    </div>
                                )
                            })}
                        </div>
                    </Section>
                </>
            )}
        </div>
    )
}
