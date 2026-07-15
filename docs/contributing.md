# Contribuir

Esta página resume cómo preparar un entorno de desarrollo para la aplicación OSeMOSYS Colombia, cómo correr sus pruebas y linters, y cómo editar y previsualizar esta misma documentación.

## Entorno de desarrollo de la aplicación

Para levantar la aplicación en primer lugar, sigue [Instalación](getting-started/installation.md) (Docker o modo local con SQLite).

### Backend

```bash
cd backend
pytest                                        # toda la suite de pruebas
pytest tests/test_visualization_configs.py    # un solo archivo
```

### Frontend

```bash
cd frontend
npm run typecheck   # verificación de tipos (tsc --noEmit)
npm run lint        # eslint
```

!!! tip "Antes de proponer un cambio"
    Corre `pytest` en el backend y `npm run typecheck` más `npm run lint` en el frontend antes de abrir un cambio. Son las mismas verificaciones que se esperan en revisión.

## Editar y previsualizar este sitio de documentación

Este sitio de documentación es un proyecto **independiente** del repositorio de la aplicación (vive en su propio directorio, separado del código de OSeMOSYS Colombia). Está construido con [MkDocs](https://www.mkdocs.org/) y el tema [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/), y también está dockerizado para facilitar su edición.

Desde la raíz de este proyecto de documentación.

```bash
docker compose up
```

Esto levanta un contenedor que ejecuta `mkdocs serve` internamente y sirve el sitio con recarga en caliente. Los cambios en los archivos `.md` se reflejan automáticamente en el navegador sin reiniciar el contenedor. El sitio queda disponible en [http://localhost:8001](http://localhost:8001).

### Estructura del sitio

El contenido vive en `docs/` (Markdown), organizado en las secciones que define la navegación (`nav`) de `mkdocs.yml` (Getting Started, Guía de Usuario, Arquitectura y Referencia, Operación, Ejemplos). Las extensiones de Markdown habilitadas incluyen admonitions (`!!! tip`, `!!! note`), pestañas, bloques de código con resaltado y tarjetas en grilla (`grid cards`) para páginas tipo landing como la portada. Al agregar una página nueva, hay que registrarla en la sección `nav` de `mkdocs.yml` para que aparezca en el menú de navegación.

## Siguientes pasos

Para continuar, revisa [Instalación](getting-started/installation.md), que tiene el detalle completo de puesta en marcha de la aplicación, y [Arquitectura](architecture/overview.md), que da el contexto técnico completo antes de contribuir cambios de fondo.
