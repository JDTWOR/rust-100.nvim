# Diseño de interacción

## Dirección visual

Una interfaz de terminal tranquila, con jerarquía tipográfica clara y los colores del tema activo. El panel usa una sola ventana flotante con borde redondeado; no necesita iconos especiales ni plugins de interfaz adicionales.

## Panel del curso

```text
 RUST 100                                             COURSE

  18 / ~100 ejercicios completados
  ━━━━━━━━━━━━──────────────────────────────────────

  Ahora
  03_ticket_v1 / 06_ownership
  La lección y el ejercicio se abrirán en ventanas lado a lado.

  ✓ 01_intro / 00_welcome
  ✓ 01_intro / 01_syntax
  ✓ 02_basic_calculator / 00_intro
  › 03_ticket_v1 / 06_ownership
    03_ticket_v1 / 07_setters
    03_ticket_v1 / 08_stack

  j/k mover   Enter abrir   l lección   r verificar   ? ayuda   q cerrar
```

La cantidad total se calcula desde el índice del curso, no se fija en `100`, porque el curso describe su número como aproximado y puede cambiar.

## Vista de estudio

- Código del ejercicio en la ventana principal.
- Lección Markdown en una ventana vertical que se puede cerrar o volver a abrir.
- Atajos locales para abrir el panel, leer la lección, buscar tareas y verificar.
- Si falla la verificación, la salida queda visible en una ventana inferior y el foco vuelve al código.
- Si pasa, se actualiza el avance local y se abre el siguiente ejercicio.

## Estados

- **Preparando el curso:** clonar el repositorio oficial al directorio de datos cuando no exista un checkout detectable.
- **Preparando verificación:** instalar `wr` con Cargo en segundo plano si falta.
- **Curso listo:** mostrar el ejercicio actual, el avance y acciones de teclado.
- **Verificando:** indicar que `wr` está ejecutándose sin congelar Neovim.
- **Resuelto:** mostrar confirmación y ofrecer el siguiente ejercicio.
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
