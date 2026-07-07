# OSeMOSYS Colombia — Documentación

Sitio de documentación (MkDocs + Material) para **OSeMOSYS Colombia**, la plataforma web de planeación energética de largo plazo de UPME construida sobre [OSeMOSYS](https://osemosys.readthedocs.io/).

Este es un proyecto **independiente** del repositorio de la aplicación ([UPME-SubDemanda/Osemosys_UPME](https://github.com/UPME-SubDemanda/Osemosys_UPME)): vive en su propio repositorio, con su propio historial y su propio despliegue.

## Contenido

- **Getting Started** — instalación (con `task`, Docker Compose o modo local) y primera simulación.
- **Guía de Usuario** — escenarios, simulaciones, visualizaciones y carga de datos Excel/SAND.
- **Arquitectura y Referencia** — vistas C4 (contexto, contenedores, componentes), motor de simulación, frontend y backend.
- **Operación** — runbook, CI/CD, despliegue.
- **Ejemplos** — archivos SAND de referencia.

## Editar y previsualizar este sitio

Requiere Docker.

```bash
docker compose up
```

El sitio queda disponible en [http://localhost:8001](http://localhost:8001), con recarga automática al editar cualquier archivo en `docs/` o `mkdocs.yml`.

Para un build estático (sin servidor):

```bash
docker compose exec docs mkdocs build --strict
```

## Estructura

```
docs/            Contenido fuente del sitio (Markdown)
mkdocs.yml        Configuración de MkDocs (tema, nav, plugins)
diagrams/         Diagramas Mermaid sueltos (para pegar en mermaid.ai/mermaid.live)
Dockerfile        Imagen de la herramienta de docs (Python + MkDocs Material)
docker-compose.yml
requirements-docs.txt
```

## Stack

[MkDocs](https://www.mkdocs.org/) + [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/), con soporte de diagramas [Mermaid](https://mermaid.js.org/) (incluye vistas C4).
