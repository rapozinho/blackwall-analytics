import { Link, Route, Routes } from "react-router-dom";
import BasesPage from "./pages/BasesPage";
import GalleryPage from "./pages/GalleryPage";
import ChartPage from "./pages/ChartPage";

export default function App() {
  return (
    <div className="app">
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
  );
}
