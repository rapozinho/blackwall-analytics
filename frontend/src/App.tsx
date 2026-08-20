import { Link, Route, Routes } from "react-router-dom";
import BasesPage from "./pages/BasesPage";
import GalleryPage from "./pages/GalleryPage";
import ChartPage from "./pages/ChartPage";
import { JobsProvider } from "./lib/jobs";
import { DEMO } from "./lib/demo";
import DemoBanner from "./components/DemoBanner";
import LangSwitch from "./components/LangSwitch";

export default function App() {
  return (
    // O acompanhamento das consultas fica acima das rotas: trocar de tela não
    // pode interromper o que já está rodando no servidor.
    <JobsProvider>
      <div className="app">
        <header className="topbar">
          <Link to="/" className="brand">◾ BlackWall Analytics</Link>
          {/* Idioma no header e nao na tela inicial: a escolha vale para todas as
              telas, e quem entra por link direto numa consulta tambem troca. */}
          <LangSwitch />
        </header>
        {/* Abaixo do header: nada fica acima da marca, e o aviso da demo não
            empurra a barra para dentro da página. */}
        {DEMO && <DemoBanner />}
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
