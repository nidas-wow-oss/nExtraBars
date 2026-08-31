===============================================================================
nExtraBars v2.2.2 - BUGFIX RELEASE (COMPLETO)
===============================================================================

CAMBIOS EN ESTA VERSIÓN:
-------------------------
✓ ARREGLADO: Bug de la barra de mascota cuando la PET recibe Fear
✓ ARREGLADO: Bug cuando el JUGADOR Y LA PET reciben Fear simultáneamente
✓ ARREGLADO: Desincronización de la pet bar con cualquier efecto de CC

El problema principal era que el addon NO escuchaba los eventos correctos
cuando el jugador o la mascota perdían control. Ahora se maneja correctamente
TODOS los casos:
  • Solo la pet recibe Fear/Polymorph/Hibernate
  • Solo el jugador recibe Fear/Stun/etc
  • Ambos reciben CC al mismo tiempo


CAMBIOS TÉCNICOS DETALLADOS:
-----------------------------
• Agregados eventos de MASCOTA al sistema de botones:
  - PET_BAR_UPDATE
  - PET_BAR_UPDATE_COOLDOWN  
  - UNIT_PET

• Agregados eventos de CONTROL DEL JUGADOR:
  - PLAYER_CONTROL_LOST (cuando pierdes control por Fear, Stun, etc.)
  - PLAYER_CONTROL_GAINED (cuando recuperas control)
  - UNIT_AURA (detecta cuando player o pet reciben/pierden debuffs)

• Estos eventos disparan actualización completa de botones incluso durante
  combate, asegurando sincronización perfecta con la barra de mascota de Blizzard.


INSTALACIÓN:
------------
1. Cierra WoW completamente
2. Ve a tu carpeta de addons:
   Interface\AddOns\

3. Si tienes la versión antigua de nExtraBars:
   - Haz un backup de la carpeta completa (por las dudas)
   - Borra o renombra la carpeta vieja

4. Copia la carpeta "nExtraBars_v2.2.2" a Interface\AddOns\

5. Renombra la carpeta a "nExtraBars" (sin el v2.2.2)

6. Inicia WoW - tus configuraciones guardadas se mantendrán


VERIFICACIÓN Y TESTING:
-----------------------
Una vez en el juego:

1. Escribe /neb para abrir el panel de opciones
2. Verifica que diga "version 2.2.2" en el código

3. PRUEBA ESTOS ESCENARIOS:
   a) Deja que un mob le de Fear a tu mascota
      → La barra debe mantenerse correctamente
   
   b) Deja que te den Fear a TI
      → La barra de mascota NO debe bugearse
   
   c) Que te den Fear a ti Y a la mascota al mismo tiempo
      → Ambas barras deben mantenerse sincronizadas
   
   d) Otros efectos CC: Polymorph, Hibernate, Stun, etc.
      → Todo debe funcionar correctamente


QUÉ ESPERAR:
------------
ANTES (BUGEADO):
• Mascota recibe Fear → Barra se desinc roniza ❌
• Jugador recibe Fear → Barra de pet se bugea ❌
• Ambos reciben Fear → Caos total ❌

DESPUÉS (ARREGLADO):
• Mascota recibe Fear → Barra se mantiene sincronizada ✓
• Jugador recibe Fear → Barra de pet funciona perfecto ✓
• Ambos reciben Fear → Todo sincronizado correctamente ✓


SOPORTE:
--------
Si TODAVÍA tienes problemas después de instalar esta versión:

1. Asegúrate de que la carpeta se llame exactamente "nExtraBars"
2. Verifica que no tengas otros addons de barras conflictuando
3. Prueba con /reload después de cada cambio
4. Si persiste, borra la carpeta WTF del personaje y reconfigura


NOTAS TÉCNICAS:
---------------
• La actualización ahora se dispara en CUALQUIER cambio de aura en player/pet
• Los botones se actualizan incluso durante InCombatLockdown para las
  funciones que no requieren cambios seguros (texturas, estados, cooldowns)
• El watcher original que solo reposicionaba frames ahora trabaja en conjunto
  con el sistema de eventos de botones


===============================================================================
Autor: Nidhaus
Bugfix por: Claude (Anthropic)
Versión: 2.2.2
Fecha: 2026-04-12
===============================================================================
