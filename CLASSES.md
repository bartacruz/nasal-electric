# Electric Classes

### System
- **new**(name, update_period=0.1,path="/systems/electrical/")
    
    creates a new electric system.
    
    update_period: in seconds. If 0 it'll run on every frame.
    
    path: base property path for publishing
- **connect**(source,load....)

    Connects 2 or more elements, and add them to the internal tree.

    If there's more than 2, it'll create a chain of source/loads for each pair of consecutive elements.

    ie: To create a 15A landing light and hook it to the main bus via a 20A breaker:
    ```
    var mysystem = electric.System.new("mysystem");
    var main_bus = electric.Wire.new("main", etc-);
    var breaker = electric.Breaker.new("landing-light",20);
    var light = electric.Light.new("landing-light",15);
    
    # Main bus is the source of the breaker, and the breaker is the load of the bus.
    mysystem.connect(main_bus, breaker);
    
    #The breaker is the source of the light, and the light is the load of the breaker.
    mysystem.connect(breaker,light);
    ```
    
    Since the method suports chaining, you could also write the connect calls in one line
    ```
    mysystem.connect(main_bus, breaker , light );
    ```
- **enable**()

    Starts the main loop
- **disable**()
    
    Stops the main loop

- **add_light**(source, name, amps, breaker_amps=0)

    Convenient method for adding a light, connected to a source with an optional breaker.

    If breaker_amps is not specified, it'll connect the light directly to the source

    Example: Instead of
    ```
    mysystem.connect(
        main_bus,
        Breaker.new("landing-light",10),
        Light.new("landing-light",9)
    )
    ```
    You could do a much cooler
    ```
    mysystem.add_light(main_bus,"landing-light,9,10)
    ```
## Sources
### Alternator
- **new**(name,source,volts,amps,rpm_threshold=800)

    Creates a new alternator instance.
    * source: the property path of the RPM source of this alternator (ie: "/engines/engine[0]/rpm")
    * volts: the rated voltage of this alternator (ie: 14.0 or 28.0)
    * amps: the rated current of this alternator (ie: 80)
    * rpm_threshold: 


### Battery
Batteries are used as a primary power source, but as they are capable of recharging, they must be connected also as a load (This behaviour may change in the future...) .

The battery will charge when it's source voltage is greater than it's own voltage.

Example:
```
var battery = e.Battery.new("battery",12,32.0,cc_amps=240.0,charge_amps=2.0);
var battery_switch = e.Switch.new("battery-switch");
# Connect the battery to the main_bus using a switch
e_system.connect(battery,battery_switch, main_bus);
# Reverse connection for loading the battery...
e_system.connect(main_bus,battery_switch,battery);
```
- new(name, volts,amps,cc_amps, charge_amps=nil,charge_percent=nil)

    Creates a new Battery
    * **volts**: rated volts (normally, 12 or 24)
    * **amps**: rated amps/hour.
    * **cc_amps**: cold crank amps
    * **charge_amps**: the max amps/hour for recharging. By default is 30% of battery rated amps/hour.
    * **charge_percent**: between 0 and 1 (default).


### ExternalPower
TODO

## Loads

### Load
TODO

### Light
TODO

### Annunciator
TODO

### Instrument
TODO

## Misc elements
### Wire
TODO
### Bus
TODO
### Switch
TODO
### Breaker
TODO


     
