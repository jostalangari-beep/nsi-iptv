# NSI IPTV - Compilacion Automatica de APK en GitHub

Este repositorio compila automaticamente el archivo `app-release.apk` de **NSI IPTV** para Android TV, Google TV, TV Box y celulares, usando el motor VLC en modo software (compatible con audio satelital AC3/MP2) y trafico local HTTP habilitado (`192.168.2.150`).

## Como descargar el APK
1. Ve a la pestana **Actions** en la parte superior del repositorio.
2. Espera a que termine el flujo **Compilar NSI IPTV APK** (se pondra un chulo verde).
3. Entra al flujo completado y baja hasta la seccion **Artifacts**.
4. Haz clic en **NSI-IPTV-APK** para descargar el archivo comprimido con tu `.apk` listo para instalar.

## Televisores Samsung (Tizen) y LG (webOS)
Copia el archivo `samsung_lg_web/index.html` dentro de la carpeta web de tu servidor `192.168.2.150` y abre `http://192.168.2.150/index.html` desde el navegador del televisor.
