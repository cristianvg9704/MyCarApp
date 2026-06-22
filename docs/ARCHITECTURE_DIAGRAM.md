# Diagrama de Arquitectura - MyCar App

## Arquitectura General

```mermaid
graph TB
    subgraph Init[Inicialización]
        A[main.dart] --> B[WidgetsFlutterBinding]
        B --> C[Inicializar Locales ES]
        C --> D[Inicializar Supabase]
        D --> E[Inicializar SQLite DB]
        E --> F[MyCarApp Widget]
    end

    subgraph Config[Configuración]
        G[AppConfig] --> H{Modo Dev/Prod}
        I[SupabaseConfig] --> J[Credenciales]
    end

    subgraph Providers[State Management]
        K[AuthProvider] --> L[Supabase Auth]
        M[UserProvider] --> N[Supabase Metadata]
        P[CarProvider] --> Q[DatabaseHelper]
        R[IncomeProvider] --> Q
    end

    subgraph Router[Navegación]
        U[GoRouter] --> V[Redirect Logic]
        V --> W{Modo Dev?}
        W -->|Sí| X[Onboarding]
        W -->|No| Y{Onboarding?}
        Y -->|No| X
        Y -->|Sí| Z{Autenticado?}
        Z -->|No| AA[Login]
        Z -->|Sí| AB[Home]
    end

    F --> G
    F --> I
    F --> K
    F --> M
    F --> P
    F --> R
    F --> U
```

## Flujo de Inicialización

```mermaid
sequenceDiagram
    participant App as main.dart
    participant Config as AppConfig
    participant Supabase as SupabaseConfig
    participant DB as DatabaseHelper
    participant Router as GoRouter

    App->>Config: Verificar modo
    App->>Supabase: Inicializar
    App->>DB: Inicializar SQLite
    App->>Router: Configurar rutas
    Router->>Config: Verificar modo dev
    alt Modo Dev
        Router->>Router: Redirigir a onboarding
    else Modo Prod
        Router->>Router: Verificar preferencias
    end
```

## Flujo de Autenticación

```mermaid
flowchart TD
    A[Usuario abre app] --> B{Modo Dev?}
    B -->|Sí| C[Onboarding]
    B -->|No| D{Onboarding?}
    D -->|No| C
    D -->|Sí| E[Login]
    C --> E
    E --> F{Usuario tiene cuenta?}
    F -->|No| G[Register]
    F -->|Sí| H[AuthProvider.signIn]
    G --> I[Crear en Supabase]
    H --> J{Exitoso?}
    J -->|No| E
    J -->|Sí| K[Home Screen]
```

## Navegación Principal

```mermaid
graph LR
    A[Onboarding] --> B[Login]
    B --> C[Register]
    B --> D[Forgot Password]
    B --> E[Main Navigation]
    E --> F[Home]
    E --> G[Incomes]
    E --> H[Profile]
    E --> I[Settings]
    F --> J[Car Detail]
    J --> K[Charts]
```

## Componentes Principales

### Providers
- AuthProvider: Autenticación Supabase
- UserProvider: Datos usuario (Supabase + SQLite)
- CarProvider: Vehículos (SQLite)
- IncomeProvider: Ingresos (SQLite)
- AppProvider: Tema/Config

### Servicios
- DatabaseHelper: SQLite local
- SupabaseConfig: Cliente Supabase

### Modelos
- Car, Income, User

### Configuración
- AppConfig: Dev/Prod mode
- MyCarColors: Paleta colores
- AppTheme: Temas

## Notas

1. Base de Datos Dual: SQLite local + Supabase
2. Modo Dev: Onboarding siempre visible
3. Modo Prod: Onboarding solo primera vez
4. Navegación: GoRouter con redirect condicional
