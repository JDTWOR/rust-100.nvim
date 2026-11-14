# Diseño de interacción

## Dirección visual

Una interfaz de terminal tranquila, con jerarquía tipográfica clara y los colores del tema activo. El panel usa una sola ventana flotante con borde redondeado; no necesita iconos especiales ni plugins de interfaz adicionales.

## Panel del curso

```text
  RUST 100                                      TALLER DE RUST

  AVANCE   18 / 98 resueltos
  ━━━━━━━━━━━━──────────────────────────────────────

  EJERCICIO ACTUAL
  03_ticket_v1 / 06_ownership
  Tarea: completa los métodos de ownership.

  MAPA DEL CURSO
  ✓ 01_intro / 00_welcome
  ✓ 01_intro / 01_syntax
  ✓ 02_basic_calculator / 00_intro
  › 03_ticket_v1 / 06_ownership
    03_ticket_v1 / 07_setters
    03_ticket_v1 / 08_stack

  j/k mover   Enter abrir   l leer teoría   r comprobar   q cerrar
```

La cantidad total se calcula desde el índice del curso, no se fija en `100`, porque el curso describe su número como aproximado y puede cambiar.

## Vista de estudio

- Código del ejercicio a ancho completo, con el cursor en el primer marcador de código.
- El winbar muestra ejercicio, avance y acciones disponibles.
- La lección Markdown abre en una vista de lectura con ajuste de línea y vuelve al código con `q`.
- Guardar el código verifica el ejercicio automáticamente; se puede desactivar en la configuración.
- Si falla, la salida completa se abre en una división inferior y el código queda visible; `q` cierra el resultado.
- Si pasa, el panel marca el ejercicio como resuelto y el usuario elige cuándo avanzar.

## Estados

- **Preparando el curso:** clonar el repositorio oficial al directorio de datos cuando no exista un checkout detectable.
- **Preparando verificación:** instalar `wr` con Cargo en segundo plano si falta.
- **Leyendo:** mostrar la lección a ancho completo con texto ajustado al terminal.
- **Curso listo:** mostrar el ejercicio actual, el avance y acciones de teclado.
- **Verificando:** indicar que `wr` está ejecutándose sin congelar Neovim.
- **Resuelto:** mostrar confirmación y esperar a que la persona avance.
- **Fallo:** mantener la salida completa de `wr` disponible para revisar.
- **Dependencia base ausente:** explicar si falta Git o Cargo, que son necesarios para completar la preparación automática.

## Atajos del panel

| Tecla | Acción |
| --- | --- |
| `j` / `k` | Moverse por la lista |
| `Enter` | Abrir el ejercicio seleccionado |
| `l` | Abrir su lección Markdown |
| `r` | Verificar el ejercicio actual |
| `?` | Mostrar ayuda |
| `q` / `Esc` | Cerrar el panel |
