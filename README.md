# ESP-IDF_and_VSCode_include_path

This repository has a script that allows you to add an include path for the ESP-IDF framework without using plugins. It is important to note that this path addition is only available for a specific project, not for all. This is done because of the dependency on sdkconfig.h which is generated for each project during its build.

IMPORTANT: The script destroys the previous contents of the .vscode/settings.json file, so if the file already exists, copy its contents to a separate file, then after execution append to the new file created by the script.

To use this script, ESP-IDF must already be installed.
It also requires the jq package to work, which can be easily installed using 
```
sudo apt install jq
```
or a similar command. You can do without this program, but then you need to comment the line in the script with this command.
At the moment of running the script, you need to assemble at least an empty project for a specific microcontroller.

This script has only been tested for the ESP32 microcontroller, but should work for other microcontrollers as well.

For ESP32, you also need to add the following lines before including the header files:
```
// Need for freertos/FreeRTOS.h include header with XTENSA arch or ESP32 MCU
#include "../build/config/sdkconfig.h"
#if (CONFIG_IDF_TARGET_ARCH_XTENSA == 1)
#define __XTENSA__ 1
#else
#define __XTENSA__ 0
#endif // __XTENSA__
```

If someone has a desire and already certain decisions to improve this script, you can always make changes to the script.
