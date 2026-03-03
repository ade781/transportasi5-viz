import { NavLink, useLocation } from 'react-router-dom'

const NAV_ITEMS = [
    { to: '/map', icon: '🗺️', label: 'Peta & Koridor', desc: 'Visualisasi spasial' },
    { to: '/arm', icon: '🔗', label: 'Association Rules', desc: 'FP-Growth mining' },
    { to: '/gmm', icon: '📊', label: 'GMM Clustering', desc: 'Gaussian Mixture' },
]

export default function Layout({ children }) {
    const location = useLocation()
    const current = NAV_ITEMS.find(n => location.pathname.startsWith(n.to))

    return (
        <div className="app-layout">
            <nav className="top-nav">
                <div className="nav-left">
                    <div className="nav-brand">
                        <span className="brand-icon">🚌</span>
                        <div className="brand-text">
                            <span className="brand-title">TransJakarta Analytics</span>
                            <span className="brand-sub">Dashboard Visualisasi</span>
                        </div>
                    </div>
                </div>
                <div className="nav-center">
                    {NAV_ITEMS.map(item => (
                        <NavLink
                            key={item.to}
                            to={item.to}
                            className={({ isActive }) =>
                                `nav-tab ${isActive ? 'active' : ''}`
                            }
                        >
                            <span className="nav-tab-icon">{item.icon}</span>
                            <span className="nav-tab-label">{item.label}</span>
                        </NavLink>
                    ))}
                </div>
                <div className="nav-right">
                    {current && (
                        <span className="nav-breadcrumb">
                            {current.icon} {current.desc}
                        </span>
                    )}
                </div>
            </nav>
            <main className="main-content">
                {children}
            </main>
        </div>
    )
}
