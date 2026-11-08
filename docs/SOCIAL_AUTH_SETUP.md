# Iniciar sesión con Apple y Google

La app usa los SDK nativos (`sign_in_with_apple`, `google_sign_in`) y cambia el token por una sesión de Supabase con
`signInWithIdToken`. Si es la primera vez, Supabase crea la cuenta; por eso el mismo botón sirve para iniciar sesión y
para registrarse. **Sin la configuración de abajo los botones muestran un mensaje de error en vez de funcionar.**

Apple exige ofrecer "Iniciar sesión con Apple" cuando una app ofrece login con Google (guía 4.8), así que los dos
proveedores se publican juntos.

## 1. Apple (solo iOS)

1. **Apple Developer → Certificates, Identifiers & Profiles → Identifiers →** `com.cris.newMyCarApp` → activa
   **Sign in with Apple** y guarda.
2. **Xcode:** abre `ios/Runner.xcworkspace` → target **Runner** → **Signing & Capabilities** → **+ Capability** →
   **Sign in with Apple**. Esto crea `Runner.entitlements` y lo enlaza al proyecto.
3. **Supabase → Authentication → Providers → Apple:** actívalo y en **Client IDs** escribe el bundle id
   `com.cris.newMyCarApp`. Para el flujo nativo no hace falta secret ni Services ID.
4. Prueba en un iPhone real o un simulador con una cuenta de Apple iniciada.

## 2. Google (iOS y Android)

1. **Google Cloud Console →** APIs y servicios → **Pantalla de consentimiento de OAuth** (tipo Externo; agrega tu
   correo y los datos de la app).
2. **Credenciales → Crear credenciales → ID de cliente de OAuth**, tres veces:
   - **Aplicación web** → es el *Web client ID*. Copia su ID y su secret.
   - **iOS** → bundle id `com.cris.newMyCarApp`. Copia el *iOS client ID* y su *reversed client ID*.
   - **Android** → paquete `com.cris.new_my_car_app` y la huella **SHA-1** de tu firma
     (`cd android && ./gradlew signingReport`; registra la de debug y la de release/Play).
3. **Supabase → Authentication → Providers → Google:** actívalo y pega el *Web client ID* y el secret.
   Activa **Skip nonce checks** (en iOS el plugin de Google no envía nonce).
4. **iOS, `ios/Runner/Info.plist`:** agrega el *reversed client ID* como esquema de URL:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array><string>com.googleusercontent.apps.XXXXXXXX-XXXX</string></array>
     </dict>
   </array>
   ```
5. **IDs en la app:** ponlos en tu `.env` (no se versiona; ver `.env.example`):
   ```
   GOOGLE_WEB_CLIENT_ID=XXXX.apps.googleusercontent.com
   GOOGLE_IOS_CLIENT_ID=YYYY.apps.googleusercontent.com
   ```
   (`GOOGLE_IOS_CLIENT_ID` solo en iOS.) Se cargan con `flutter run --dart-define-from-file=.env`; las
   configuraciones de `.vscode/launch.json` ya lo incluyen.
6. Tras agregar el plugin hay que recompilar por completo (`flutter clean`, `pod install` en iOS).

## 3. Cuentas y datos
- **Mismo correo:** si alguien ya se registró con correo y contraseña y luego entra con Google/Apple con el mismo
  correo, Supabase vincula las identidades al mismo usuario (por defecto *Link accounts with the same email*).
- **Nombre:** Google lo trae en el perfil; Apple solo lo entrega la primera vez y la app lo guarda en `user_metadata.name`.
  El teléfono no se pide en este flujo.
- **Apple y "correo privado":** el usuario puede ocultar su correo; Supabase recibe un correo de retransmisión de Apple.

## 4. Pendiente importante para la App Store
Al **eliminar la cuenta** de un usuario que entró con Apple, Apple exige además **revocar el token** de Sign in with Apple
(guía 5.1.1(v)). Hoy `delete_my_account()` borra los datos y el usuario de Supabase pero **no revoca el token en Apple**.
Hacerlo requiere un servidor: una Edge Function que firme un client secret (JWT) con tu clave `.p8` y llame a
`https://appleid.apple.com/auth/revoke`. Hasta implementarlo, la revisión puede observarlo.
