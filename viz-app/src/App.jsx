import { Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import MapPage from './pages/MapPage'
import ARMPage from './pages/ARMPage'
import GMMPage from './pages/GMMPage'

export default function App() {
    return (
        <Layout>
            <Routes>
                <Route path="/" element={<Navigate to="/map" replace />} />
                <Route path="/map" element={<MapPage />} />
                <Route path="/arm" element={<ARMPage />} />
                <Route path="/gmm" element={<GMMPage />} />
            </Routes>
        </Layout>
    )
}
