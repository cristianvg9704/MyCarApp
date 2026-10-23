# Skills del proyecto

Cada skill vive en su propia carpeta con un `SKILL.md`:

```
.claude/skills/
└── nombre-del-skill/
    ├── SKILL.md        # obligatorio
    └── ...             # archivos de apoyo opcionales (ejemplos, plantillas)
```

`SKILL.md` empieza con frontmatter:

```markdown
---
name: nombre-del-skill
description: Cuándo usar este skill (una línea, se usa para decidir si aplica)
---

Instrucciones, convenciones y ejemplos de código a seguir.
```

Antes de escribir código, se consulta el skill que aplique y se sigue lo que define.
