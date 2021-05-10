# IoTrigger

<img src="https://raw.githubusercontent.com/IoTrim/iotrimlist/master/system.png" width="1000"/>

To mitigate non-essential IoT traffic, we propose a blocking system composed of two components: IoTrigger and IoTrimmer. The former runs our <a href="http://iotrim.net">methodology</a> to produce (non-)required destination lists, and the latter uses such lists with a blocking strategy to generate firewall traffic-blocking rules. 
IoTrigger runs on a router providing connectivity to a set of IoT devices to test. It manages the lifecycle of functionality experiments for each device, including the invocation of user-provided trigger and probe scripts, and to finally produce (non-)required destination lists. To work, IoTrigger needs the IoT devices connected to the same router, the list of their IP addresses, the scripts to trigger and probe their functions, and any other auxiliary devices (e.g., devices used by trigger/probes scripts). Given this, IoTrigger will run the experiment and generate the destinations lists without any human interaction. We implemented a command-line prototype of IoTrigger, which includes a library of probes and triggers scripts that support the IoT devices we tested. Anyone owning the same IoT devices, and the proper trigger devices (e.g., Android phones) can use the IoTrigger prototype to reproduce our results. For new devices and new functions, new trigger/probe scripts must be added.

HOW TO RUN THE SOFTWARE

