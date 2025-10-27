| Componente                                                                | Propósito                                                                                        | Por qué lo necesitamos en este proyecto                                      |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| **Airflow** (fuera de k8s)                                                | Orquestar la simulación de llegada de datos (cada 5 min, lotes de 15k), limpieza y entrenamiento | Automatiza el flujo de datos y el reentrenamiento incremental/acumulativo    |
| **MLflow** (fuera de k8s)                                                 | Tracking de experimentos, registro de modelos, transición a `Production`                         | Fuente de verdad del mejor modelo; controla versiones para servir en la API  |
| **PostgreSQL**                                              | Backend store de MLflow                                                                          | Persiste metadatos de runs/modelos                                           |
| **MinIO**  | Artefactos (modelos, métricas) y opcionalmente RAW/CLEAN                                         | S3 local compatible con MLflow, simple y portable                            |
| **FastAPI** (en k8s)                                                      | API de inferencia (`/predict`, `/health`, `/metrics`)                                            | Expone el modelo `Production` sin redeploy; integra Prometheus               |
| **Streamlit** (en k8s)                                                    | UI para el usuario final                                                                         | Permite ingresar datos, ejecutar inferencias y mostrar **qué modelo** se usó |
| **Prometheus** (en k8s)                                                   | Recolecta métricas de FastAPI (`/metrics`)                                                       | Observabilidad cuantitativa (latencias, RPS, errores)                        |
| **Grafana** (en k8s)                                                      | Visualiza métricas; dashboards **versionados** en Git                                            | Observabilidad reproducible, evidencias y reportes                           |
| **Locust** (en k8s)                                                       | Pruebas de carga sobre la API                                                                    | Determina concurrencia máxima estable y latencias (P50/P95/P99)              |

### Estructura proyecto 

```bash
mlops-proyecto3/
│
├── README.md                     # Documentación principal (instrucciones de uso)
├── .env.example                  # Variables de entorno base
├── docker-compose.yml            # Orquestador local (stack completo)
├── Makefile                      # Comandos útiles (build, up, test, etc.)
│
├── data/
│   ├── raw/                      # Datos sin procesar (batches 15k)
│   ├── clean/                    # Datos limpios (parquet/csv)
│   └── metadata_batch.json       # Estado del batch actual (para Airflow)
│
├── ml/                           # Lógica de ciencia de datos
│   ├── preprocess.py             # Limpieza y transformación de datos
│   ├── train.py                  # Entrenamiento de modelos (usado por Airflow)
│   ├── utils.py                  # Funciones auxiliares (logging, métricas, etc.)
│   └── requirements.txt          # Dependencias específicas de ML
│
├── compose/                      # Stack de servicios (modo Docker Compose)
│   │
│   ├── airflow/                  # Orquestación de pipelines ETL y entrenamiento
│   │   ├── dags/
│   │   │   ├── dag_ingest_raw.py         # Simula llegada 15k cada 5 min
│   │   │   ├── dag_process_clean.py      # Limpieza y features
│   │   │   └── dag_train_register.py     # Entrena + registra modelo + promueve
│   │   ├── requirements.txt              # Dependencias (mlflow, boto3, sklearn, etc.)
│   │   └── Dockerfile                    # Imagen base para Airflow
│   │
│   ├── mlflow/                  # MLflow + backend store (Postgres) + artifacts (MinIO)
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── config/
│   │       ├── mlflow.env       # Configuración del tracking server
│   │       └── backend_store.db # Si se usa SQLite en desarrollo
│   │
│   ├── postgres/                # Base de datos para MLflow
│   │   ├── init.sql             # Script inicial de esquema o permisos
│   │   └── Dockerfile
│   │
│   ├── minio/                   # Almacenamiento de artefactos
│   │   ├── Dockerfile
│   │   └── config/
│   │       └── credentials.env
│   │
│   ├── prometheus/              # Recolección de métricas
│   │   └── prometheus.yml
│   │
│   ├── grafana/                 # Visualización y dashboards versionados
│   │   ├── dashboards/
│   │   │   ├── api_overview_v1.json
│   │   │   ├── README.md
│   │   └── provisioning/
│   │       ├── datasources/
│   │       │   └── datasource.yaml
│   │       └── dashboards/
│   │           └── dashboards.yaml
│   │
│   ├── fastapi/                 # Servicio de inferencia (modelo Production)
│   │   ├── app.py               # Main FastAPI app
│   │   ├── model_io.py          # Carga del modelo desde MLflow
│   │   ├── schemas.py           # Definición de inputs/outputs
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   │
│   ├── streamlit/               # Interfaz de usuario
│   │   ├── app.py               # Interfaz con formulario y respuesta
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   │
│   ├── locust/                  # Pruebas de carga sobre la API
│   │   ├── locustfile.py        # Escenarios de prueba
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   │
│   └── prometheus/              # Configuración adicional (alertas, etc.)
│       └── prometheus.yml
│
├── k8s/                         # Manifiestos Kubernetes (base + overlays)
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── fastapi.yaml         # Deployment + Service
│   │   ├── streamlit.yaml       # Deployment + Service
│   │   ├── prometheus.yaml      # Deployment + ConfigMap + Service
│   │   ├── grafana.yaml         # Deployment + Service
│   │   └── locust.yaml          # Deployment + Service
│   │
│   └── overlays/
│       └── minikube/
│           ├── kustomization.yaml
│           └── patches/
│               ├── nodeport-streamlit.yaml
│               ├── nodeport-grafana.yaml
│               └── storage-hostpath.yaml
│
├── docs/                        # Documentación y evidencias del proyecto
│   ├── architecture_diagram.png
│   ├── grafana_screenshots/
│   ├── locust_results/
│   └── report.md
│
└── tests/                       # Scripts o notebooks de validación
    ├── test_fastapi_requests.py
    ├── test_model_predictions.py
    └── test_airflow_dags.py
```

## MODELO

* Se carga la base de datos.
* Se identifica el tamaño, tiene 101766 filas y, 50 columnas.
* Se identifica que el simbolo '?' es una forma de poner un null, vacio o dato faltante. Se procede a reemplazarlo como una notacion NaN.
* Se identifica el tipo de dato
* Identificar el porcentaje de datos faltantes por variable.

* A1Cresult y max_glu_serum son variables las cuales el nan corresponde a prueba no aplicada
