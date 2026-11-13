# Propuesta de trabajo

## Estado actual

- La estructura del curso y el flujo de `wr` ya están revisados en sus repositorios oficiales.
- El diseño de interacción está documentado en [UX.md](UX.md).
- La base Lua implementa navegación, quickfix, estado local y verificación asíncrona. En el primer uso clona el curso oficial si hace falta e instala `wr` en el directorio de datos de Neovim.
- La primera ejecución crea el archivo JSON de progreso automáticamente, incluso cuando aún no existe.

## Objetivo

Crear un plugin de Neovim que acompañe el curso *100 Exercises to Learn Rust* durante todo el ciclo de estudio: leer, resolver, verificar y continuar, con el menor cambio posible de contexto.

El plugin debe sentirse integrado con Neovim, ser claro en terminales pequeñas y respetar el tema activo. La interfaz inicial será sobria, navegable con teclado y sin dependencias visuales obligatorias.

## Hallazgos que orientan el diseño

- El curso ya trae teoría en Markdown, paquetes Rust por ejercicio y pruebas.
- `wr` ya verifica el ejercicio actual y mantiene el avance del taller.
- Rustlings inspira la navegación, las pistas y la localización de `TODO`; aquí conviene reutilizar los marcadores de cada ejercicio y dedicar el plugin a conectar lectura, edición y verificación.
- El material del curso está publicado bajo CC BY-NC 4.0. El flujo previsto debe trabajar sobre una copia local del repositorio oficial y conservar su atribución.

### Validación técnica inicial

- `wr open --chapter <capítulo> --exercise <ejercicio>` registra un ejercicio para el runner.
- `wr check`, ejecutado desde la carpeta del ejercicio, corre solo ese ejercicio y termina con un código de salida útil para Neovim.
- `wr` sin subcomando comprueba los ejercicios abiertos y puede preguntar si debe abrir el siguiente. `wr --keep-going` abre y prueba automáticamente los siguientes; no encaja con el avance paso a paso deseado.
- `wr` guarda su progreso en SQLite, en `exercises/progress.db`. El esquema es un detalle interno del runner, así que el plugin no lo leerá directamente.
- Las rutas de `book/src/SUMMARY.md` siguen el mismo capítulo y nombre base que los paquetes bajo `exercises/`; el plugin puede resolver la pareja sin copiar el contenido del curso.
- El `.wr.toml` del curso está vacío y el runner usa `exercises` como ruta predeterminada.
- En el entorno de desarrollo hay Neovim 0.12.6 y Rust 1.96.0. El flujo automático de instalación de `wr` debe confirmarse con una ejecución real del runner.

**Decisión para la primera versión:** guardar el capítulo actual y los ejercicios aprobados por el plugin en un archivo JSON bajo el directorio de estado de Neovim. En cada verificación, registrar el ejercicio con `wr open` y ejecutar `wr check`. Así se mantiene el progreso de `wr` y la sesión de Neovim sin depender de su SQLite. Si se usa `wr` directamente fuera del plugin, la lista local puede requerir reanudación manual; sincronizar ese caso queda para una fase posterior.

## Recorrido propuesto

1. `:Rust100` abre el panel, detecta un checkout o clona el curso; también instala `wr` en segundo plano si hace falta.
2. El panel muestra capítulo, ejercicio actual, avance y acciones disponibles.
3. Abrir el ejercicio prepara una vista de código y una vista Markdown de la lección.
4. La búsqueda de tareas lleva los `TODO` y `todo!()` a quickfix.
5. `:Rust100 check` ejecuta `wr` de forma asíncrona y presenta la salida en Neovim.
6. Si la verificación permite avanzar, el plugin abre la siguiente lección y su ejercicio.

La fase técnica determinará el comando y el formato de estado fiables para consultar el progreso de `wr`; no se asumirá una API que el runner no documente.

## Fases

### 0. Validación técnica

- Inspeccionar el checkout del curso y mapear `book/src` a `exercises`.
- Confirmar cómo `wr` verifica, avanza y guarda el estado, incluidos sus casos de error.
- Comprobar el soporte del workspace con `rust-analyzer` y la detección del curso desde cualquier subdirectorio.
- Fijar Neovim 0.10 como mínimo para usar `vim.system()` y ejecutar `wr` sin bloquear el editor.
- Registrar las decisiones en notas breves de arquitectura.

**Salida:** un diseño de integración comprobado y una lista cerrada de requisitos.

### 1. Diseño de interacción

- Dibujar el panel de inicio, la vista de estudio y la salida de verificación.
- Definir comandos, estados vacíos, errores de dependencias y atajos.
- Revisar el comportamiento con pocos colores, fuentes sin iconos y ventanas pequeñas.

**Salida:** una guía visual y de navegación que pueda implementarse sin dependencias obligatorias.

### 2. Estructura base del plugin

- Crear módulos Lua, configuración y comandos públicos.
- Detectar la raíz del curso y añadir `:checkhealth` para Git, Rust, `wr` y la estructura esperada.
- Evitar sobrescribir soluciones, archivos existentes o configuración del usuario.

**Salida:** plugin cargable que detecta o clona el checkout y prepara `wr` automáticamente cuando Git y Cargo están disponibles.

### 3. Lecciones, ejercicios y tareas

- Navegar capítulos desde el índice del libro.
- Abrir la lección Markdown y el paquete Rust correspondiente.
- Encontrar `TODO` y `todo!()` en el ejercicio activo y enviarlos a quickfix.

**Salida:** recorrido de lectura y edición completo, todavía sin asumir automatismos de progreso.

### 4. Verificación y progreso

- Ejecutar `wr` en segundo plano y mostrar su salida sin congelar Neovim.
- Distinguir ejecución, éxito y fallo con texto legible y colores del tema activo.
- Avanzar únicamente cuando el runner confirme que el ejercicio está resuelto.
- Añadir comprobación al guardar como opción desactivada por defecto.

**Salida:** ciclo completo de resolver, verificar y continuar.

### 5. Pulido y distribución

- Revisar estados vacíos, errores comunes, sesiones reanudadas y terminales pequeñas.
- Documentar instalación con `lazy.nvim`, comandos, configuración y dependencias.
- Preparar ejemplos visuales y una lista de comprobaciones manuales para cada versión.

**Salida:** primera versión instalable, explicada y lista para compartir.

## Primer hito

Entregar un recorrido vertical mínimo:

- Dado un checkout local del curso, encontrar una lección y su ejercicio.
- Abrir ambos dentro de Neovim.
- Ejecutar la verificación oficial de forma asíncrona.
- Mostrar el resultado y, al aprobar, continuar al ejercicio siguiente.

Este hito valida la integración principal antes de invertir tiempo en un dashboard más elaborado.

## Criterios de aceptación de la primera versión

- El usuario puede completar ejercicios de varios capítulos sin salir de Neovim.
- Se conservan las soluciones y el progreso oficial del runner al cerrar y reabrir el editor.
- La sesión del plugin se reanuda tras cerrar y reabrir el editor cuando el curso se recorre desde el plugin.
- Un fallo de compilación o de pruebas muestra salida útil y permite seguir editando.
- La ejecución no bloquea el editor.
- Los comandos funcionan desde la raíz del curso y desde un archivo de ejercicio.
- La interfaz se entiende sin iconos especiales y con temas claros u oscuros.
- El contenido upstream conserva su atribución y no se copia al repositorio del plugin.

## Riesgos y decisiones abiertas

1. **Estado de `wr`:** el runner no ofrece un comando documentado para consultar progreso; la vista inicial usa estado propio del plugin.
2. **Licencia:** decidir la licencia del código del plugin; el contenido de Mainmatter conserva su CC BY-NC 4.0.
3. **Versión mínima de Neovim:** fijada en 0.10 por la API `vim.system()`.
4. **Instalación del curso:** resuelto; reutiliza un checkout detectado o clona el curso oficial al directorio de datos de Neovim. `course_root` permite elegir otra ruta.
5. **Auto check:** mantenerlo opcional y desactivado inicialmente para evitar ejecuciones inesperadas.

## Convención de commits

Los mensajes de commit se escribirán en inglés. El asunto describirá el cambio en modo imperativo; el cuerpo explicará el motivo, el alcance y las comprobaciones realizadas. Se usará un tipo convencional cuando ayude a entender el historial, por ejemplo `docs: define initial project proposal`.
