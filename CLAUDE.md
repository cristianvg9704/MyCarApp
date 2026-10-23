# NewMyCarApp

## Skills
El código de este proyecto se escribe basándose en los skills de `.claude/skills/`.
Antes de implementar o modificar código, revisa el skill que aplique y sigue sus convenciones.

### Skill por feature (documentación)
Cada feature nueva debe tener su skill en `.claude/skills/<feature>/SKILL.md` que documente:
qué hace, archivos y capas involucradas (screens, providers, services, models), reglas de negocio,
tablas/RLS de Supabase si aplica, y cómo se prueba. Si una feature existente cambia, actualiza su skill.
La feature no está terminada hasta que su skill existe y está al día.

### UI
Para construir UI, sigue el skill de UI del proyecto (design system Material 3: tema, tokens de color,
tipografía, componentes reutilizables). No hardcodear colores/estilos en las pantallas; usar el tema.

## Explorar el código
- Usa el MCP `graphify` para leer/entender el código en lugar de abrir todos los archivos.
- Si el grafo está desactualizado (`graphify-out/` más viejo que los cambios recientes en `lib/`, o la
  información no coincide), lee los archivos directamente.
- Antes de editar un archivo, léelo directamente aunque el grafo lo describa.

## Tests
- Toda feature nueva que sea testeable lleva sus tests (`test/`), en la misma tarea.
- Escribe código fácil de testear: lógica de negocio fuera de los widgets (providers/services/funciones
  puras), dependencias inyectadas por constructor (no singletons ni `Supabase.instance` dentro de widgets),
  y widgets pequeños y sin efectos secundarios en `build`.
- Corre `flutter test` y `flutter analyze` antes de dar una tarea por terminada.

## Commits
- Al completar cada tarea (con tests pasando), crea un commit para poder hacer rollback.
- Un commit por tarea, mensajes estilo conventional commits (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`).
- Incluye el skill y los tests de la feature en el mismo commit.
- Haz stage solo de los archivos de la tarea; no mezcles cambios no relacionados que ya estén en el working tree.
