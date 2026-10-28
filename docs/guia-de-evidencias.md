# Guía de evidencias para KoPay

## 1. Propósito

Registrar de forma comprobable el avance del equipo y los resultados de la aplicación. Una captura del tablero muestra el estado registrado; el resultado de una prueba requiere además datos, pasos y lo que realmente ocurrió.

## 2. Evidencia por entregable

| Entregable | Evidencia mínima |
| :--- | :--- |
| Historias y plan de pruebas | Archivos `.md` revisados, con versión y criterios claros. |
| Tablero de seguimiento | Enlace al Project, tarjetas con responsable y estado, y captura fechada del cierre del ciclo. |
| Trabajo con Git | Issue o tarjeta vinculada a rama, commit y Pull Request cuando exista trabajo de código. |
| Arquitectura y patrón | Diagrama, descripción de módulos y referencia a los archivos que aplican el patrón. |
| Función demostrada | Caso de prueba con fecha, dispositivo, resultado y captura o video del efecto visible. |
| APK | Archivo entregado, versión, dispositivo en que se instaló y registro del caso de instalación. |

## 3. Registro breve de una prueba

Copiar este formato al ejecutar cada caso. Mantener **Pendiente** mientras no se haya probado.

```text
Caso: INT-01
Fecha y hora:
Responsable:
Versión o commit:
Dispositivo y sistema:
Datos usados:
Pasos realizados:
Resultado esperado:
Resultado observado:
Estado: Pendiente / Aprobado / Fallido
Evidencia: enlace o nombre de archivo
Issue de defecto, si aplica:
```

Los casos y resultados esperados se encuentran en [plan-de-pruebas.md](plan-de-pruebas.md). No asignar retrospectivamente fechas, responsables o resultados que el equipo no pueda respaldar.

## 4. Seguimiento del ciclo

Al iniciar un ciclo, anotar objetivo, fechas acordadas, tarjetas seleccionadas y responsables. Durante el trabajo, mover cada tarjeta a su estado real y registrar bloqueos. Al cierre, guardar una captura del [Project indicado por el equipo](https://github.com/users/JanettheMillan/projects/3) y enlazar los Issues, Pull Requests y resultados de prueba correspondientes. La existencia de un enlace al Project no demuestra por sí misma que las tareas ya estén asignadas o realizadas.

## 5. Nombres sugeridos de archivos

- `INT-01-gasto-movimientos.png`
- `INT-01-resumen.png`
- `UI-07-validacion-pago.png`
- `sprint-01-tablero-AAAA-MM-DD.png`
- `apk-instalacion-AAAA-MM-DD.png`

Guardar únicamente evidencia real. Evitar información financiera personal o credenciales en capturas.
