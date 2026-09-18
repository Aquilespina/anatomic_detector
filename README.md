# Anatomic AI — Detector de Postura

Una aplicación de Flutter (Android/iOS) que ayuda a llevar un seguimiento
fotográfico de la postura de espalda de una persona, usando dos modelos de
inteligencia artificial que corren **directamente en el teléfono**, sin
mandar ninguna foto a internet.

Este documento explica cómo está armada la app en términos simples, pensado
para alguien que no tiene por qué saber de programación ni de redes
neuronales.

> **Importante:** esto es una herramienta de seguimiento y detección
> temprana, no un diagnóstico médico. Un resultado de "Posible escoliosis"
> es una señal para consultar a un especialista, no una confirmación.

---

## 1. ¿Qué hace la app, paso a paso?

1. Elegís un **espacio de trabajo** (más abajo se explica qué es esto).
2. Sacás una foto de espalda (o elegís una de la galería).
3. La app ubica automáticamente **17 puntos del cuerpo** sobre la foto:
   nariz, ojos, orejas, hombros, codos, muñecas, caderas, rodillas y
   tobillos.
4. Con esos puntos, calcula un puñado de **medidas de simetría** — por
   ejemplo, si un hombro queda más alto que el otro, o si las caderas están
   parejas.
5. Esas medidas (no la foto) se las pasa a un segundo modelo, entrenado
   específicamente para distinguir posturas típicas de posturas con
   posible escoliosis, que devuelve un resultado con un porcentaje de
   confianza.
6. Guardás ese resultado — opcionalmente asociado a una persona — para
   poder comparar más adelante cómo evolucionó.

## 2. Los dos "cerebros" de la app

La app no usa un único modelo de IA, sino **dos, encadenados**, y ambos
vienen incluidos en la app misma (no se descargan ni se consultan por
internet):

### Modelo 1 — el que "mira" la foto (detector de pose)

Recibe la foto y devuelve la ubicación de los 17 puntos del cuerpo
mencionados arriba, cada uno con un porcentaje de confianza ("qué tan
seguro está de que ahí hay, por ejemplo, un hombro"). Es un modelo de
propósito general para reconocer cuerpos humanos en fotos, no fue
entrenado para escoliosis.

### Modelo 2 — el "especialista" (clasificador de postura)

Este es el que sí fue entrenado con el problema puntual de postura/columna
en mente. Un detalle importante: **este modelo nunca ve la foto**. Solo
recibe 10 números calculados a partir de los 17 puntos (diferencias de
altura entre hombros, entre caderas, ángulos, simetría de brazos, etc.) —
es como si a un especialista solo le pasaran una planilla de medidas, sin
mostrarle la imagen.

Con esos 10 números, devuelve un resultado:

| Resultado | Qué significa |
|---|---|
| **Saludable** | La postura está dentro de los parámetros típicos. |
| **Posible escoliosis** | Se detectan asimetrías; se sugiere consulta especializada. |
| **Indeterminado** | El caso es ambiguo, no hay una lectura clara para ningún lado. |
| **Error** | Algo falló al procesar el análisis (no es un resultado clínico, es un problema técnico puntual). |

### Por qué esto importa para la confiabilidad del resultado

Como el segundo modelo solo ve números calculados a partir de la foto (no
la foto en sí), la **calidad de esos 17 puntos es todo lo que tiene para
trabajar**. Por eso la app hace un trabajo extra antes de analizar:

- Si la foto tiene un **marco blanco o un borde uniforme** (por ejemplo,
  una foto tipo polaroid o con relleno blanco), la app lo detecta y lo
  recorta antes de analizar, para que la persona no quede "achicada"
  dentro del cuadro.
- Si la foto es de **proporción rectangular** (la mayoría lo son), ya no
  se la aplasta ni estira para volverla cuadrada como pedía el modelo —
  se mantiene la proporción real y se rellena lo que sobra con un gris
  neutro, como hacen los sistemas de reconocimiento de imágenes en
  general.
- Si la foto es **muy chica**, se agranda antes de analizar para no
  perder detalle.

## 3. Espacios de trabajo (cómo se separan los datos de cada usuario)

La app está pensada para que la puedan usar **varias personas distintas en
el mismo teléfono** (por ejemplo, más de un profesional, o distintos
consultorios) sin que una vea la información de la otra. A esto, en
informática, se le llama **multi-tenant** ("multi-inquilino"): varios
"inquilinos" comparten el mismo edificio (la misma app, la misma base de
datos), pero cada uno tiene su propio departamento, con llave propia.

En esta app, cada "departamento" es un **espacio de trabajo**:

- Cada espacio tiene su propia lista de **personas** y su propio
  **historial de análisis** — un espacio nunca puede ver los datos de
  otro.
- Se pueden crear tantos espacios como se necesiten, ponerles un nombre
  propio, renombrarlos o eliminarlos (eliminar un espacio borra también,
  de forma permanente, todo lo que tenía guardado).
- Por debajo, técnicamente, todos los espacios viven en el mismo archivo
  de base de datos del teléfono, pero cada análisis y cada persona
  guardan una etiqueta invisible (a qué espacio pertenecen), y la app
  siempre filtra por esa etiqueta antes de mostrar cualquier dato. Es la
  misma idea que separar cajones con nombre dentro de un mismo mueble.
- Hay una excepción a propósito: se puede **copiar (importar) una
  persona**, con todo su historial, de un espacio a otro — por ejemplo,
  para tener datos de prueba en un espacio nuevo, o cuando la misma
  persona real necesita seguimiento en dos espacios distintos. Es una
  copia real, así que después son independientes: modificar una no toca
  la otra.

## 4. ¿Dónde se guardan los datos?

Todo — la base de datos y las fotos guardadas — queda **almacenado
localmente en el teléfono**, en una carpeta privada de la app. Nada se
sube a un servidor ni se comparte por internet. Esto también significa
que si se desinstala la app o se pierde el dispositivo, esos datos no se
pueden recuperar desde ningún otro lado: no hay copia en la nube.

## 5. Mapa del proyecto (para quien quiera mirar el código)

```
lib/
  screens/    → las pantallas que se ven (elegir espacio, dashboard,
                nuevo análisis, personas, historial, comparación)
  services/   → el "motor" de la app: la base de datos local y los dos
                modelos de IA (detector de pose y clasificador)
  models/     → las "fichas" de datos: un análisis, una persona, un
                espacio de trabajo
  providers/  → quién es el espacio de trabajo activo en cada momento
  theme/      → colores y estilos compartidos por toda la app
  widgets/    → piezas reutilizables, como la tarjeta de guía para
                tomar la foto
```

## 6. Cómo correr el proyecto

Requiere tener [Flutter](https://docs.flutter.dev/get-started/install)
instalado.

```bash
flutter pub get
flutter run
```

Para generar el instalador de Android:

```bash
flutter build apk --release
```
