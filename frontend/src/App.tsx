import { Link, Route, Routes } from "react-router-dom";
import BasesPage from "./pages/BasesPage";
import GalleryPage from "./pages/GalleryPage";
import ChartPage from "./pages/ChartPage";
import { JobsProvider } from "./lib/jobs";
import { DEMO } from "./lib/demo";
import DemoBanner from "./components/DemoBanner";

export default function App() {
  return (
    // O acompanhamento das consultas fica acima das rotas: trocar de tela não
    // pode interromper o que já está rodando no servidor.
    <JobsProvider>
      <div className="app">
        {DEMO && <DemoBanner />}
        <header className="topbar">
          <Link to="/" className="brand">◾ BlackWall Analytics</Link>
        </header>
        <main className="content">
          <Routes>
            <Route path="/" element={<BasesPage />} />
            <Route path="/:base" element={<GalleryPage />} />
            <Route path="/:base/:chartId" element={<ChartPage />} />
          </Routes>
        </main>
      </div>
    </JobsProvider>
  );
}
