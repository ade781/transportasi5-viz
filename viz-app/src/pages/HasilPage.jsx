import { useEffect, useMemo, useState } from 'react'
import { CLUSTER_COLORS, loadCSV, normalizeCorridor } from '../utils'

function Section({ title, subtitle, children }) {
    return (
        <section className="hasil-block">
            <div className="hasil-block-head">
                <h2>{title}</h2>
                {subtitle && <p>{subtitle}</p>}
            </div>
            {children}
        </section>
    )
}

function StatCard({ label, value, sub, color }) {
    return (
        <div className="hasil-stat-card" style={{ borderTopColor: color }}>
            <span className="hasil-stat-label">{label}</span>
            <strong className="hasil-stat-value">{value}</strong>
            {sub && <span className="hasil-stat-sub">{sub}</span>}
        </div>
    )
}

function fmtInt(value) {
    return Number(value || 0).toLocaleString('id-ID')
}

function fmtPct(value, digits = 1) {
    return `${Number(value || 0).toFixed(digits)}%`
}

function fmtRatioPct(value, digits = 1) {
    return `${(Number(value || 0) * 100).toFixed(digits)}%`
}

function clampPercent(value, maxValue) {
    if (!maxValue) return 0
    return Math.max(0, Math.min(100, (Number(value || 0) / Number(maxValue)) * 100))
}

function describeCluster(profile, topRule, armSummary) {
    const hour = Number(profile.mean_tapIn_hour || 0)
    const duration = Number(profile.mean_duration_min || 0)
    const weekend = Number(profile.pct_weekend || 0)
    const trips = Number(profile.mean_n_trips || 0)
    const activeDays = Number(profile.mean_n_days_month || 0)

    const timeNarrative =
        hour < 7 ? 'berangkat sangat pagi' :
            hour < 10 ? 'berangkat pada jam komuter pagi' :
                hour >= 16 ? 'berangkat pada pola pulang kerja sore' :
                    'berpergian di tengah hari'

    const intensityNarrative =
        trips >= 4 ? 'intensitas perjalanan paling tinggi di antara semua cluster' :
            trips >= 2 ? 'intensitas perjalanan menengah dan cukup rutin' :
                'frekuensi perjalanan relatif rendah'

    const weekendNarrative =
        weekend >= 40 ? 'aktivitas akhir pekan sangat dominan' :
            weekend >= 15 ? 'masih memiliki campuran weekday dan weekend' :
                'sangat terkonsentrasi pada hari kerja'

    const durationNarrative =
        duration >= 90 ? 'durasi perjalanan cenderung panjang sehingga mengindikasikan perpindahan lintas area yang lebih jauh' :
            duration <= 50 ? 'durasi perjalanan relatif singkat sehingga kemungkinan besar melayani perpindahan yang lebih dekat atau lebih langsung' :
                'durasi perjalanan berada pada tingkat menengah'

    const ruleNarrative = topRule
        ? `Pola transfer terkuat di cluster ini adalah ${topRule.lhs} -> ${topRule.rhs} dengan lift ${Number(topRule.lift || 0).toFixed(2)}, confidence ${fmtRatioPct(topRule.confidence, 1)}, dan ${fmtInt(topRule.count_trip)} trip.`
        : 'Tidak ada rule transfer dominan yang menonjol pada scope cluster ini.'

    const armNarrative = armSummary
        ? `Cluster ini menghasilkan ${fmtInt(armSummary.n_rules)} rule terpilih dengan rata-rata lift ${Number(armSummary.avg_lift || 0).toFixed(2)} dan rata-rata confidence ${Number(armSummary.avg_conf || 0).toFixed(1)}%.`
        : 'Jumlah dan kekuatan rule pada cluster ini tidak tersedia.'

    return [
        `Cluster ini merepresentasikan penumpang yang ${timeNarrative}. Secara operasional, pola ini penting karena ${weekendNarrative}.`,
        `Dari sisi perilaku penggunaan, cluster ini memiliki ${intensityNarrative} dengan ${Number(trips).toFixed(2)} trip per hari dan ${Number(activeDays).toFixed(2)} hari aktif per bulan. Selain itu, ${durationNarrative}.`,
        `${armNarrative} ${ruleNarrative}`,
    ]
}

function classifyPriority(profile) {
    const weekend = Number(profile.pct_weekend || 0)
    const trips = Number(profile.mean_n_trips || 0)
    const share = Number(profile.pct_obs || 0)
    if (share >= 25 || trips >= 4) return 'Tinggi'
    if (weekend >= 40) return 'Menengah'
    return 'Menengah'
}

export default function HasilPage() {
    const [profiles, setProfiles] = useState([])
    const [rulesGlobal, setRulesGlobal] = useState([])
    const [rulesCluster, setRulesCluster] = useState([])
    const [halte, setHalte] = useState([])
    const [clusterStats, setClusterStats] = useState([])
    const [modelSelection, setModelSelection] = useState([])
    const [armSummary, setArmSummary] = useState([])
    const [loading, setLoading] = useState(true)
    const [error, setError] = useState('')

    useEffect(() => {
        let cancelled = false

        Promise.all([
            loadCSV('/data/cluster_profiles.csv'),
            loadCSV('/data/rules_global_cross.csv'),
            loadCSV('/data/rules_all_cross.csv'),
            loadCSV('/data/halte.csv'),
            loadCSV('/data/cluster_stats.csv'),
            loadCSV('/data/gmm_model_selection.csv'),
            loadCSV('/data/arm_summary_cross.csv'),
        ])
            .then(([profileRows, globalRulesRows, clusterRulesRows, halteRows, clusterStatsRows, modelRows, armSummaryRows]) => {
                if (cancelled) return
                const normalizeRules = (rows) => (rows || []).map((row) => ({
                    ...row,
                    lhs: normalizeCorridor(row.lhs),
                    rhs: normalizeCorridor(row.rhs),
                }))
                setProfiles(profileRows || [])
                setRulesGlobal(normalizeRules(globalRulesRows))
                setRulesCluster(normalizeRules(clusterRulesRows))
                setHalte(halteRows || [])
                setClusterStats(clusterStatsRows || [])
                setModelSelection(modelRows || [])
                setArmSummary(armSummaryRows || [])
                setLoading(false)
            })
            .catch((err) => {
                if (cancelled) return
                setError(err?.message || 'Gagal memuat data hasil analisis.')
                setLoading(false)
            })

        return () => {
            cancelled = true
        }
    }, [])

    const selectedModel = useMemo(() => modelSelection[0] || null, [modelSelection])

    const totalObservations = useMemo(
        () => profiles.reduce((sum, row) => sum + (Number(row.n_obs) || 0), 0),
        [profiles]
    )

    const totalUsers = useMemo(
        () => clusterStats.reduce((sum, row) => sum + (Number(row.n_users) || 0), 0),
        [clusterStats]
    )

    const totalCrossTrips = useMemo(
        () => clusterStats.reduce((sum, row) => sum + (Number(row.n_cross) || 0), 0),
        [clusterStats]
    )

    const commuterShare = useMemo(() => {
        const commuterTotal = profiles
            .filter((row) => Number(row.pct_commuter || 0) >= 95)
            .reduce((sum, row) => sum + (Number(row.pct_obs) || 0), 0)
        return commuterTotal
    }, [profiles])

    const dominantWorkdayShare = useMemo(() => {
        return profiles
            .filter((row) => Number(row.pct_weekend || 0) < 20)
            .reduce((sum, row) => sum + (Number(row.pct_obs) || 0), 0)
    }, [profiles])

    const topCluster = useMemo(
        () => [...profiles].sort((a, b) => Number(b.pct_obs || 0) - Number(a.pct_obs || 0))[0] || null,
        [profiles]
    )

    const globalTopRules = useMemo(() => (
        [...rulesGlobal]
            .filter((row) => row.lhs && row.rhs && row.lhs !== row.rhs)
            .sort((a, b) => {
                const tripDiff = Number(b.count_trip || b.count || 0) - Number(a.count_trip || a.count || 0)
                if (tripDiff !== 0) return tripDiff
                return Number(b.lift || b.lift_global || 0) - Number(a.lift || a.lift_global || 0)
            })
            .slice(0, 5)
    ), [rulesGlobal])

    const clusterRuleMap = useMemo(() => {
        const map = new Map()
        rulesCluster.forEach((row) => {
            const cluster = Number(row.cluster)
            const current = map.get(cluster)
            if (!current || Number(row.lift || 0) > Number(current.lift || 0)) {
                map.set(cluster, row)
            }
        })
        return map
    }, [rulesCluster])

    const armSummaryMap = useMemo(() => {
        const map = new Map()
        armSummary.forEach((row) => {
            map.set(Number(row.cluster), row)
        })
        return map
    }, [armSummary])

    const corridorDemand = useMemo(() => {
        const totals = new Map()
        halte.forEach((row) => {
            const corridor = normalizeCorridor(row.corridorName)
            const passengers = Number(row.total_penumpang_bulan) || 0
            if (!corridor) return
            totals.set(corridor, (totals.get(corridor) || 0) + passengers)
        })
        return [...totals.entries()]
            .map(([corridor, passengers]) => ({ corridor, passengers }))
            .sort((a, b) => b.passengers - a.passengers)
            .slice(0, 8)
    }, [halte])

    const maxCorridorDemand = useMemo(
        () => Math.max(...corridorDemand.map((row) => Number(row.passengers || 0)), 0),
        [corridorDemand]
    )

    const clusterNarratives = useMemo(() => (
        profiles
            .map((profile) => {
                const clusterId = Number(profile.cluster)
                return {
                    ...profile,
                    priority: classifyPriority(profile),
                    topRule: clusterRuleMap.get(clusterId) || null,
                    arm: armSummaryMap.get(clusterId) || null,
                    narrative: describeCluster(profile, clusterRuleMap.get(clusterId), armSummaryMap.get(clusterId)),
                }
            })
            .sort((a, b) => Number(a.cluster) - Number(b.cluster))
    ), [armSummaryMap, clusterRuleMap, profiles])

    const mainFindings = useMemo(() => {
        const findings = []
        if (selectedModel) {
            findings.push(`Model Gaussian Mixture Model terbaik berada pada konfigurasi ${selectedModel.selected_model || selectedModel.best_bic_model} dengan K=${selectedModel.selected_k || selectedModel.best_bic_k}. Konfigurasi ini dipilih karena paling selaras dengan referensi BIC pada eksperimen model.`)
        }
        if (topCluster) {
            findings.push(`Cluster terbesar adalah ${topCluster.label} dengan proporsi ${fmtPct(topCluster.pct_obs, 2)}. Artinya, struktur mobilitas paling dominan dalam data adalah pola ${topCluster.label.toLowerCase()} dan bukan perjalanan acak yang tersebar merata.`)
        }
        findings.push(`Secara agregat, ${fmtPct(commuterShare, 2)} observasi berada pada segmen dengan karakter komuter sangat kuat, dan ${fmtPct(dominantWorkdayShare, 2)} observasi terkonsentrasi pada pola hari kerja. Ini menunjukkan bahwa sistem TransJakarta terutama menopang mobilitas rutin, bukan sekadar perjalanan insidental.`)
        findings.push(`Association Rule Mining menunjukkan bahwa transfer antar koridor tidak menyebar merata ke seluruh jaringan. Pola perpindahan terkonsentrasi pada pasangan koridor tertentu, sehingga intervensi operasional paling efektif adalah yang diarahkan ke simpul pertukaran utama, bukan disamaratakan ke seluruh rute.`)
        return findings
    }, [commuterShare, dominantWorkdayShare, selectedModel, topCluster])

    const managementActions = useMemo(() => ([
        {
            title: 'Penguatan layanan jam puncak kerja',
            horizon: 'Jangka pendek',
            detail: 'Prioritaskan penyesuaian headway pada cluster Commuter Pagi Dini, Commuter Pagi, dan Commuter Sore karena tiga cluster ini membentuk arus utama sistem. Fokus intervensi harus pada ketepatan waktu bus pertama, kepadatan sebelum jam kerja, dan arus pulang kerja sore.',
        },
        {
            title: 'Perbaikan simpul transfer prioritas',
            horizon: 'Jangka pendek',
            detail: 'Pasangan koridor dengan lift tinggi menunjukkan perpindahan yang tidak kebetulan. Halte transfer pada pasangan rule dominan perlu diperbaiki dari sisi wayfinding, informasi perpindahan, penataan antrean, dan integrasi jadwal layanan.',
        },
        {
            title: 'Diferensiasi layanan weekday dan weekend',
            horizon: 'Jangka menengah',
            detail: 'Cluster Penumpang Kasual memiliki dominasi akhir pekan yang kuat. Karena itu, pola informasi layanan, kesiapan armada, dan strategi feeder pada akhir pekan tidak seharusnya identik dengan hari kerja.',
        },
        {
            title: 'Monitoring koridor berbeban tinggi',
            horizon: 'Jangka menengah',
            detail: 'Koridor dengan akumulasi penumpang halte tertinggi perlu menjadi objek audit berkala untuk dwell time, antrian halte, dan kestabilan waktu tempuh. Beban yang tinggi pada koridor yang sama berpotensi menimbulkan bottleneck sistemik.',
        },
        {
            title: 'Layanan untuk pengguna sangat intensif',
            horizon: 'Jangka menengah',
            detail: 'Cluster Penumpang Intensif walau kecil secara proporsi, memiliki trip per hari dan hari aktif per bulan paling tinggi. Ini menandakan keberadaan pengguna yang sangat bergantung pada sistem, sehingga keandalan dan konsistensi koneksi antar koridor menjadi lebih penting daripada sekadar kapasitas.',
        },
        {
            title: 'Pengembangan analisis lanjutan',
            horizon: 'Jangka panjang',
            detail: 'Temuan ini sudah cukup kuat sebagai dasar eksplorasi kebijakan, tetapi tetap perlu dilanjutkan dengan analisis musiman, integrasi antar moda, serta evaluasi berbasis data operasional yang lebih lengkap agar keputusan manajemen makin presisi.',
        },
    ]), [])

    if (loading) {
        return (
            <div className="loading">
                <div className="loading-spinner" />
                <span>Memuat halaman hasil analisis...</span>
            </div>
        )
    }

    if (error) {
        return (
            <div className="hasil-page hasil-v2">
                <div className="hasil-error">{error}</div>
            </div>
        )
    }

    return (
        <div className="hasil-page hasil-v2">
            <div className="hasil-hero">
                <div className="hasil-hero-copy">
                    <span className="hasil-overline">Bab 4 - Hasil dan Pembahasan</span>
                    <h1>Hasil Analisis Mobilitas Penumpang TransJakarta</h1>
                    <p>
                        Halaman ini dirancang sebagai sintesis akhir penelitian. Fokusnya bukan mengulang grafik eksplorasi di halaman lain,
                        tetapi menjelaskan apa hasil analisisnya, bagaimana karakteristik tiap cluster, bagaimana pola transfer yang muncul,
                        dan apa implikasinya bagi manajemen TransJakarta.
                    </p>
                </div>
                <div className="hasil-stat-grid">
                    <StatCard label="Model GMM Terpilih" value={selectedModel ? `${selectedModel.selected_model || selectedModel.best_bic_model} / K=${selectedModel.selected_k || selectedModel.best_bic_k}` : '-'} sub="hasil seleksi model akhir" color="#2563eb" />
                    <StatCard label="Total Observasi" value={fmtInt(totalObservations)} sub="basis segmentasi perilaku" color="#0891b2" />
                    <StatCard label="Total Pengguna" value={fmtInt(totalUsers)} sub="akumulasi user dalam cluster" color="#7c3aed" />
                    <StatCard label="Trip Transfer" value={fmtInt(totalCrossTrips)} sub="total cross-corridor teridentifikasi" color="#dc2626" />
                </div>
            </div>

            <Section title="Inti Hasil Penelitian" subtitle="Ringkasan ini merangkum hasil paling penting dari integrasi GMM dan Association Rule Mining.">
                <div className="hasil-insight-grid">
                    <div className="hasil-insight-card hasil-insight-primary">
                        <h3>Kesimpulan utama</h3>
                        <p>
                            Struktur mobilitas penumpang TransJakarta tidak homogen. Hasil clustering menunjukkan adanya lima segmen perilaku
                            yang berbeda secara temporal dan intensitas penggunaan, sementara hasil ARM membuktikan bahwa perpindahan koridor
                            terkonsentrasi pada jalur-jalur tertentu yang berfungsi sebagai tulang punggung transfer.
                        </p>
                    </div>
                    <div className="hasil-insight-list">
                        {mainFindings.map((text, index) => (
                            <div key={index} className="hasil-finding-item">
                                <span className="hasil-finding-index">0{index + 1}</span>
                                <p>{text}</p>
                            </div>
                        ))}
                    </div>
                </div>
            </Section>

            <Section title="Komposisi Segmen Penumpang" subtitle="Visual berikut memperlihatkan besarnya tiap cluster secara relatif tanpa mengulang chart dari halaman GMM.">
                <div className="hasil-strip-wrap">
                    {clusterNarratives.map((cluster) => (
                        <div key={cluster.cluster} className="hasil-strip-row">
                            <div className="hasil-strip-label">
                                <span className="hasil-cluster-dot" style={{ background: CLUSTER_COLORS[cluster.cluster] }} />
                                <strong>{`C${cluster.cluster} - ${cluster.label}`}</strong>
                                <span>{fmtPct(cluster.pct_obs, 2)}</span>
                            </div>
                            <div className="hasil-strip-track">
                                <div
                                    className="hasil-strip-fill"
                                    style={{
                                        width: `${Number(cluster.pct_obs || 0)}%`,
                                        background: CLUSTER_COLORS[cluster.cluster],
                                    }}
                                />
                            </div>
                        </div>
                    ))}
                </div>
                <div className="hasil-body-text">
                    <p>
                        Tiga cluster komuter utama, yaitu Commuter Pagi Dini, Commuter Pagi, dan Commuter Sore, membentuk mayoritas besar
                        observasi. Ini menegaskan bahwa beban utama sistem berada pada perjalanan rutin hari kerja yang berlangsung pada
                        jendela waktu berulang. Sementara itu, cluster Penumpang Kasual tampil sebagai segmen yang berbeda jelas karena
                        aktivitas akhir pekan dan frekuensi bulanan yang jauh lebih rendah.
                    </p>
                </div>
            </Section>

            <Section title="Karakteristik Setiap Cluster" subtitle="Bagian ini menjabarkan makna operasional dari masing-masing cluster secara naratif dan terukur.">
                <div className="hasil-cluster-grid">
                    {clusterNarratives.map((cluster) => (
                        <article key={cluster.cluster} className="hasil-cluster-card">
                            <div className="hasil-cluster-head" style={{ borderColor: CLUSTER_COLORS[cluster.cluster] }}>
                                <div>
                                    <span className="hasil-cluster-id" style={{ color: CLUSTER_COLORS[cluster.cluster] }}>{`C${cluster.cluster}`}</span>
                                    <h3>{cluster.label}</h3>
                                </div>
                                <span className="hasil-priority-chip">{cluster.priority}</span>
                            </div>

                            <div className="hasil-cluster-metrics">
                                <div className="hasil-mini-metric">
                                    <span>Proporsi</span>
                                    <strong>{fmtPct(cluster.pct_obs, 2)}</strong>
                                </div>
                                <div className="hasil-mini-metric">
                                    <span>Jam tap-in</span>
                                    <strong>{Number(cluster.mean_tapIn_hour).toFixed(2)}</strong>
                                </div>
                                <div className="hasil-mini-metric">
                                    <span>Durasi</span>
                                    <strong>{Number(cluster.mean_duration_min).toFixed(1)} mnt</strong>
                                </div>
                                <div className="hasil-mini-metric">
                                    <span>Trip per hari</span>
                                    <strong>{Number(cluster.mean_n_trips).toFixed(2)}</strong>
                                </div>
                                <div className="hasil-mini-metric">
                                    <span>Hari aktif</span>
                                    <strong>{Number(cluster.mean_n_days_month).toFixed(2)}</strong>
                                </div>
                                <div className="hasil-mini-metric">
                                    <span>Weekend</span>
                                    <strong>{fmtPct(cluster.pct_weekend, 2)}</strong>
                                </div>
                            </div>

                            <div className="hasil-meter-group">
                                <div className="hasil-meter">
                                    <span>Porsi cluster</span>
                                    <div className="hasil-meter-track">
                                        <div className="hasil-meter-fill" style={{ width: `${Number(cluster.pct_obs || 0)}%`, background: CLUSTER_COLORS[cluster.cluster] }} />
                                    </div>
                                </div>
                                <div className="hasil-meter">
                                    <span>Intensitas trip</span>
                                    <div className="hasil-meter-track">
                                        <div className="hasil-meter-fill" style={{ width: `${clampPercent(cluster.mean_n_trips, 5)}`, background: CLUSTER_COLORS[cluster.cluster] }} />
                                    </div>
                                </div>
                                <div className="hasil-meter">
                                    <span>Orientasi weekend</span>
                                    <div className="hasil-meter-track">
                                        <div className="hasil-meter-fill" style={{ width: `${Number(cluster.pct_weekend || 0)}%`, background: CLUSTER_COLORS[cluster.cluster] }} />
                                    </div>
                                </div>
                            </div>

                            <div className="hasil-cluster-text">
                                {cluster.narrative.map((paragraph, index) => (
                                    <p key={index}>{paragraph}</p>
                                ))}
                            </div>

                            <div className="hasil-cluster-rulebox">
                                <strong>Koridor dominan</strong>
                                <span>{cluster.top_corridor || '-'}</span>
                                {cluster.topRule && (
                                    <>
                                        <strong>Rule terkuat per cluster</strong>
                                        <span>{`${cluster.topRule.lhs} -> ${cluster.topRule.rhs}`}</span>
                                    </>
                                )}
                            </div>
                        </article>
                    ))}
                </div>
            </Section>

            <Section title="Pola Transfer yang Paling Menonjol" subtitle="Visual ini menampilkan hotspot perpindahan global yang paling penting untuk dipantau manajemen.">
                <div className="hasil-hotspot-grid">
                    {globalTopRules.map((rule, index) => (
                        <article key={`${rule.lhs}-${rule.rhs}-${index}`} className="hasil-hotspot-card">
                            <div className="hasil-hotspot-rank">{`#${index + 1}`}</div>
                            <h3>{`${rule.lhs} -> ${rule.rhs}`}</h3>
                            <div className="hasil-hotspot-metrics">
                                <div><span>Trip</span><strong>{fmtInt(rule.count_trip || rule.count)}</strong></div>
                                <div><span>Lift</span><strong>{Number(rule.lift || rule.lift_global || 0).toFixed(2)}</strong></div>
                                <div><span>Confidence</span><strong>{fmtRatioPct(rule.confidence, 1)}</strong></div>
                                <div><span>Shared stop</span><strong>{fmtInt(rule.n_shared_stops)}</strong></div>
                            </div>
                            <p>
                                Rule ini menunjukkan pasangan perpindahan koridor yang paling aktif pada hasil global. Semakin tinggi trip dan lift,
                                semakin penting pasangan ini dipertimbangkan sebagai titik prioritas dalam pengelolaan transfer.
                            </p>
                        </article>
                    ))}
                </div>
                <div className="hasil-body-text">
                    <p>
                        Dari perspektif manajemen jaringan, hasil ARM mengindikasikan bahwa kebutuhan transfer penumpang cenderung terkonsentrasi
                        pada simpul-simpul tertentu. Artinya, strategi perbaikan pengalaman transfer seharusnya berangkat dari pasangan koridor
                        dominan seperti yang muncul pada hasil rule global dan hasil rule per cluster, bukan semata dari persebaran halte secara umum.
                    </p>
                </div>
            </Section>

            <Section title="Koridor dengan Beban Halte Tertinggi" subtitle="Daftar berikut membantu mengidentifikasi lokasi yang paling layak diaudit dari sisi kapasitas dan operasi lapangan.">
                <div className="hasil-corridor-list">
                    {corridorDemand.map((row, index) => (
                        <div key={`${row.corridor}-${index}`} className="hasil-corridor-item">
                            <div className="hasil-corridor-head">
                                <strong>{row.corridor}</strong>
                                <span>{fmtInt(row.passengers)} penumpang</span>
                            </div>
                            <div className="hasil-corridor-track">
                                <div className="hasil-corridor-fill" style={{ width: `${clampPercent(row.passengers, maxCorridorDemand)}%` }} />
                            </div>
                        </div>
                    ))}
                </div>
                <div className="hasil-body-text">
                    <p>
                        Koridor dengan volume halte tertinggi layak menjadi target awal untuk audit kapasitas, evaluasi dwell time, dan penataan
                        alur penumpang. Jika koridor-koridor ini juga beririsan dengan hotspot transfer, maka efek bottleneck dapat berlipat karena
                        tekanan terjadi baik pada naik-turun penumpang maupun perpindahan antarkoridor.
                    </p>
                </div>
            </Section>

            <Section title="Implikasi dan Rekomendasi bagi Manajemen TransJakarta" subtitle="Rekomendasi ini diturunkan langsung dari hasil segmentasi perilaku dan pola transfer yang ditemukan.">
                <div className="hasil-actions-grid">
                    {managementActions.map((action) => (
                        <article key={action.title} className="hasil-action-card">
                            <span className="hasil-action-horizon">{action.horizon}</span>
                            <h3>{action.title}</h3>
                            <p>{action.detail}</p>
                        </article>
                    ))}
                </div>
                <div className="hasil-body-text">
                    <p>
                        Secara keseluruhan, hasil penelitian ini menunjukkan bahwa kebijakan yang paling relevan bagi manajemen TransJakarta
                        adalah kebijakan yang bersifat terarah: fokus pada jam puncak komuter, titik transfer paling kuat, dan koridor dengan
                        beban halte tertinggi. Pendekatan ini lebih efisien dibandingkan distribusi intervensi yang terlalu merata ke seluruh jaringan.
                    </p>
                    <p>
                        Namun demikian, sesuai batasan penelitian pada skripsi ini, hasil yang diperoleh tetap bersifat eksploratif dan lebih tepat
                        diposisikan sebagai dasar pendukung pengambilan keputusan. Untuk implementasi kebijakan operasional langsung, temuan ini
                        sebaiknya dikombinasikan dengan data headway aktual, kapasitas armada, data load factor, dan kondisi lapangan pada halte transfer.
                    </p>
                </div>
            </Section>
        </div>
    )
}
