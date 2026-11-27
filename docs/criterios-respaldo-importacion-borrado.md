# Criterios de respaldo, importación y borrado

**Tarjeta:** S2-03 (#35) · Sprint 2
**Historias:** HU-26 (exportar Excel), HU-27 (importar CSV), HU-28 (borrar datos locales)
**Aplican a:** S2-06 (#38), S2-20 (#107) y la verificación de S2-18
**Responsable:** Rubén (RuAbogado)

Este documento fija las reglas que deben seguir S2-06 y S2-20. Si una implementación necesita apartarse de algo de aquí, se propone el cambio en este archivo antes de abrir el PR.

## 1. Tres rutas distintas

| Ruta | Formato | Qué hace | Toca los datos |
| :--- | :--- | :--- | :--- |
| Exportar | XLSX | Crea un archivo para leer en Excel y lo comparte | No |
| Importar | CSV | Reemplaza movimientos e ingresos por los del archivo | Sí, tras confirmar |
| Borrar | — | Elimina los datos financieros del dispositivo | Sí, tras confirmar |

Exportar no produce CSV e importar no acepta XLSX. Son rutas separadas y se prueban por separado, como indica el plan de pruebas.

Las tres opciones viven en la pantalla **Ajustes**.

## 2. Exportar XLSX (HU-26)

- **Nombre del archivo:** `kopay-respaldo-AAAA-MM-DD.xlsx`, con la fecha del día de la exportación.
- **Hojas, en este orden:**

| Hoja | Columnas, en este orden |
| :--- | :--- |
| `Movimientos` | Fecha · Descripción · Categoría · Importe · Nota · Tipo · De |
| `Ingresos` | Fecha · Nombre · Importe · Nota |
| `Tarjetas` | Nombre · Banco · Límite · Saldo usado · Día de corte · Día de pago · Pago mínimo |
| `Deudas` | Nombre · Monto · Saldo restante · Fecha · Estado |
| `Respaldo` | `tipo` · `fecha` · `importe` · `descripcion` · `categoria` · `nota` (formato de la sección 3) |

- **Tipos de celda:** la fecha va como fecha de Excel y el importe como número, no como texto, para que se pueda sumar y ordenar. El importe del movimiento conserva su signo (negativo = gasto). Los días de corte y de pago de `Tarjetas` van como número entero.
- **Columna `Tipo` de `Movimientos`:** `Gasto` si el importe es negativo, `Entrada` si es positivo y `Pago` si el movimiento se registró desde una tarjeta o una deuda.
- **Columna `De` de `Movimientos`:** nombre de la tarjeta o de la deuda del pago. Vacía en los movimientos que no son pagos y en los pagos cuya tarjeta o deuda ya se borró.
- **Hoja `Tarjetas`:** el saldo usado y el pago mínimo se exportan tal como están guardados; el crédito disponible no se exporta porque se calcula.
- **Hoja `Deudas`:** `Monto` es la mensualidad de la deuda y `Fecha` es el próximo vencimiento. `Estado` es `Pendiente` o `Pagada`.
- **Orden de filas:** movimientos e ingresos por fecha, de la más reciente a la más antigua. Tarjetas y deudas en el orden en que se registraron.
- **Hoja `Respaldo`:** repite los mismos movimientos e ingresos con el formato exacto de importación. Sirve para que el usuario la guarde como CSV y la pueda importar después. **No incluye los pagos**, porque el formato CSV no los admite (sección 3): al importarla, un pago no se reconstruye y el saldo de su tarjeta o deuda no cambia.
- **Sin registros:** se exporta igual, con solo los encabezados, y se avisa "No hay registros; el archivo solo tiene encabezados".
- **Compartir:** al terminar se abre la hoja de compartir del sistema. Si el usuario la cierra sin compartir, no es un error y no se muestra aviso.
- **Fallo:** si no se puede crear o compartir el archivo, se muestra un mensaje claro y los datos no cambian.

## 3. Formato CSV de importación (HU-27)

### Archivo

- Codificación UTF-8. Se acepta con o sin BOM.
- La primera fila es el encabezado, con estas columnas en este orden y escritas así:

```
tipo,fecha,importe,descripcion,categoria,nota
```

- **Separador:** coma (`,`) o punto y coma (`;`). Se detecta en la fila de encabezado. Excel en español guarda los CSV con `;`.
- Los campos con separador, comillas o saltos de línea van entre comillas dobles (RFC 4180).
- Se ignoran las filas totalmente vacías.
- Tamaño máximo: 5 MB.

### Columnas

| Columna | Obligatoria | Regla |
| :--- | :--- | :--- |
| `tipo` | Sí | `movimiento` o `ingreso`. Sin importar mayúsculas ni espacios a los lados. |
| `fecha` | Sí | `AAAA-MM-DD` o `DD/MM/AAAA`. Debe ser una fecha real: `2026-02-30` se rechaza (defecto D-03). |
| `importe` | Sí | Número sin símbolo de moneda ni separador de miles. Decimal con punto; si el separador del archivo es `;`, se acepta también coma decimal. En `movimiento` lleva signo (negativo = gasto). En `ingreso` debe ser mayor que 0. En ambos casos, máximo dos decimales y distinto de 0, igual que en los formularios. |
| `descripcion` | Sí | Texto no vacío. En `movimiento` es la descripción; en `ingreso`, el nombre. |
| `categoria` | Solo en `movimiento` | Texto no vacío de hasta 30 caracteres. En `ingreso` se deja vacía. Si no existe en la lista de categorías, se agrega al importar. |
| `nota` | No | Texto libre. Vacío se guarda como sin nota. |

Ejemplo válido:

```
tipo,fecha,importe,descripcion,categoria,nota
movimiento,2026-11-02,-250.50,Súper,Comida,
movimiento,2026-11-03,-80,Camión,Transporte,ida y vuelta
ingreso,2026-11-01,12000,Quincena,,
```

### Reglas de importación

1. **Importar reemplaza.** Los movimientos e ingresos actuales se sustituyen por los del archivo. No se agregan encima.
2. **Se valida todo antes de tocar nada.** Si cualquier fila tiene un error, la importación se cancela completa y los datos actuales no cambian.
3. **Errores visibles.** Se muestran el número de fila (contando el encabezado como fila 1) y el motivo, por ejemplo `Fila 7: fecha imposible "2026-02-30"`. Si hay más de 10, se muestran los 10 primeros y el total.
4. **Archivo sin registros.** Un archivo con solo el encabezado se rechaza con "El archivo no tiene registros". Así se evita borrar todo por accidente.
5. **Encabezado incorrecto.** Se rechaza e indica las columnas esperadas.
6. **Confirmación.** Con el archivo válido se pregunta: "Se reemplazarán tus X movimientos e Y ingresos por A movimientos y B ingresos del archivo. Esta acción no se puede deshacer." Botones: **Cancelar** y **Reemplazar**.
7. **Cancelar conserva** todos los datos actuales.
8. **Todo o nada.** El borrado y la inserción van en una sola transacción de SQLite. Si algo falla, se revierte, se avisa y quedan los datos anteriores.
9. **Qué no cambia:** moneda e idioma. Las categorías existentes se conservan; solo se agregan las nuevas que traiga el archivo.
10. **Al terminar:** Inicio y Movimientos muestran los datos importados sin reiniciar la app, y se informa "Se importaron A movimientos y B ingresos".

Tarjetas, deudas y pagos quedan fuera de este formato. La importación sigue reemplazando solo movimientos e ingresos: la hoja `Respaldo` excluye los pagos y no reconstruye saldos. Cuando se agreguen nuevos valores de `tipo`, se documentan aquí antes de implementarlos.

## 4. Borrar datos locales (HU-28)

- **Ubicación:** Ajustes → **Borrar datos**, con estilo de acción destructiva.
- **Qué borra:** solo datos financieros del dispositivo: movimientos, ingresos, tarjetas y deudas.
- **Qué conserva:** categorías, moneda e idioma.
- **Confirmación:** "¿Borrar todos tus datos? Se eliminarán movimientos, ingresos, tarjetas y deudas de este dispositivo. Tus categorías y ajustes se conservan. Esta acción no se puede deshacer." Botones: **Cancelar** y **Borrar**.
- **Cancelar conserva** todos los registros.
- **Todo o nada:** el borrado va en una transacción. Si falla, se avisa y no se borra nada.
- **Al terminar:** Inicio y Movimientos muestran su estado vacío sin reiniciar la app, y se informa "Datos borrados".
- **Datos remotos:** en el Sprint 2 no hay sincronización, así que solo se borra lo local. Cuando exista la sincronización (Sprint 3), su tarjeta documenta qué pasa con los datos del servidor.

### Entrega por partes

Las tablas de tarjetas (S2-07) y deudas (S2-08) todavía no existen. Se acuerda:

- S2-20 se implementa ya con movimientos e ingresos.
- El borrado se concentra en un solo método, `DatabaseHelper.deleteFinancialData()`, que borra todas las tablas financieras en una transacción.
- El PR de S2-20 lo anota en su descripción.
- S2-07 y S2-08 deben agregar su tabla a ese método y una prueba que lo compruebe. El revisor de esos PR lo verifica.
- S2-18 comprueba el borrado completo de las cuatro tablas cuando ya existan.

## 5. Casos críticos

Identificadores para las pruebas de S2-06, S2-20 y S2-18. Incluir el identificador en el nombre de la prueba, como pide CLAUDE.md.

| ID | Ruta | Caso | Resultado esperado |
| :--- | :--- | :--- | :--- |
| RES-01 | Exportar | Con movimientos, ingresos, tarjetas y deudas | El XLSX tiene las cinco hojas en orden, las columnas en orden y todos los registros |
| RES-02 | Exportar | Sin registros | Se crea el XLSX con solo encabezados y se avisa |
| RES-03 | Exportar | Importes y fechas | Las celdas son número y fecha, no texto; el gasto conserva el signo |
| RES-04 | Exportar → Importar | Hoja `Respaldo` guardada como CSV | Se importa y los movimientos e ingresos quedan iguales a los exportados; los pagos no están en la hoja |
| RES-05 | Exportar | Movimientos con gasto, entrada y pagos a tarjeta y deuda | La columna `Tipo` dice `Gasto`, `Entrada` o `Pago` y la columna `De` nombra la tarjeta o deuda del pago |
| IMP-01 | Importar | CSV válido con `,` | Tras confirmar, los registros del archivo reemplazan los actuales y se ven en Inicio y Movimientos |
| IMP-02 | Importar | CSV válido con `;` y coma decimal | Se importa igual que IMP-01 |
| IMP-03 | Importar | Cancelar la confirmación | Los datos actuales no cambian |
| IMP-04 | Importar | Una fila con fecha imposible | Se cancela todo, se indica la fila y los datos no cambian |
| IMP-05 | Importar | Importe no numérico o `tipo` desconocido | Se cancela todo e indica fila y motivo |
| IMP-06 | Importar | Encabezado incorrecto | Se rechaza e indica las columnas esperadas |
| IMP-07 | Importar | Solo encabezado | Se rechaza con "El archivo no tiene registros" |
| IMP-08 | Importar | Categoría que no existe | Se importa y la categoría aparece en el selector |
| IMP-09 | Importar | Fallo al escribir en la base | Se revierte y quedan los datos anteriores |
| BOR-01 | Borrar | Cancelar la confirmación | Se conservan todos los registros |
| BOR-02 | Borrar | Confirmar | Movimientos e ingresos quedan vacíos, la interfaz muestra el estado vacío y se conservan categorías, moneda e idioma |
| BOR-03 | Borrar | Con tarjetas y deudas (cuando existan) | También quedan vacías |
| BOR-04 | Borrar | Fallo al borrar | Se avisa y no se borra nada |

## 6. Librerías autorizadas

Para S2-06 se autorizan en CLAUDE.md: `excel` (crear el XLSX), `csv` (leer el CSV respetando comillas), `file_picker` (elegir el archivo), `path_provider` (carpeta temporal para el archivo) y `share_plus` (compartirlo). S2-20 no necesita librerías nuevas.
