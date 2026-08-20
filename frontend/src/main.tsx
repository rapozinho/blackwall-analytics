import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter, HashRouter } from "react-router-dom";
import App from "./App";
import { DEMO } from "./lib/demo";
import "./styles.css";

// GitHub Pages nao tem rewrite: `/Zephyr/overview` cairia em 404 antes de o
// React carregar. Na demo as rotas moram no hash; servida pelo nginx do compose,
// que ja manda tudo para o index.html, o caminho normal continua.
const Router = DEMO ? HashRouter : BrowserRouter;

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <Router>
      <App />
    </Router>
  </React.StrictMode>
);
