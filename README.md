# FlightGear Electric System
An atempt to simplify and normalize the electric simulation on FlightGear's aircrafts.

The concept is simple. 

Instantiate an electric system, add power sources, loads, and connect them using wires, buses, switches, circuit breakers, etc. and let the electric system do the calculations, manage the logic, and publish the result in the properties tree.

As a side-benefit, help to somehow normalize the properties tree, by using default locations.

### Implementation
The System.connect() method creates a tree that represents the wiring diagram.
The main loop will traverse this three applying the available voltage to the loads while collecting the current draw. Then it'll apply that load to the power sources available.
Finally, it'll publish the results in the property tree

### Normalization
By default:
- All the load classes (Load, Light, Annunciator, etc) will publish their voltage in /systems/electrical/ouputs/_name_
- Switches will read from /controls/switches/_name_
- Breakers will read from (and eventually write to) /controls/circuit-brakers/_name_
- Annunciators will read from /instrumentation/annunciators/_name_

Of course, you can change that behavior specifying a different (optional) parameter. ie: 
```
Switch.new("myswitch"); # will read from /controls/switches/myswitch
Switch.new("myotherswitch","/a/personalized/path"); # will read from a custom location
```

### Instalation
- Place the file Nasal/electric.nas inside the airplane's Nasal dir
- Declare the use inside the aircraft definition XML file.
```
<nasal>
    ....
    <electric>
        <file>Nasal/electric.nas</file>
    </electric>
    ....
</nasal>
```
### Quickstart
Create a new electric system, with a name and an update rate (in seconds).
```
var electricsystem = electric.System.new("myplanename",0.1);
```
>[!NOTE]
>An update rate of 0 will run the update on every frame. This is not recommended unless you need to do some cutting-edge calculations with your electrical system. A value of 0.1 or 0.2 should be more than enough for simulation purposes.

Now, create your power sources, loads, switches, breakers,etc. 

Create a battery, connected to the main bus via a battery-switch and a 40A breaker.
(I use a shorthand because I'm lazy...)
```
# Shorthand
var e = electric;

var battery = e.Battery.new("battery",12,25.0,cc_amps=225.0,charge_amps=2.0);
var battery_breaker = e.Breaker.new("battery",40.0);
var battery_switch = e.Switch.new("battery-switch","/controls/electric/battery-switch");
var main_bus = e.Bus.new("main-bus");
```
and connect them to each other using System.connect(source,load)
``` 
electricsystem.connect(battery,battery_breaker);
electricsystem.connect(battery_breaker, battery_switch);
electricsystem.connect(battery_switch, main_bus);
```
System.connect() supports chaining of components in the form connect(source, load&source, load&source....) so you could write that more easily
```
electricsystem.connect(battery,battery_breaker, battery_switch, main_bus);
```

Connect the starter motor
```
var starter = e.Load.new("starter",80.0,"/controls/engines/engine[0]/starter_cmd");
electricystem.connect(main_bus,starter);
```
Since connect() stores the objects in the tree, you don't need to declare a variable if you are not going to use it elsewere...
```
electricystem.connect(main_bus,e.Load.new("starter",80.0,"/controls/engines/engine[0]/starter_cmd"));
```
Connect lights, instruments, and assorted loads

A 4A Fuel pump with 5A breaker.
```
electricsystem.connect(
    main_bus,
    e.Breaker.new("fuel-pump",5.0),
    e.Load.new("fuel-pump",4.0,"/controls/fuel/tank/boost-pump")
);
```

Exterior lights with their respective breakers. 

For current calculation, take in account the system voltage.
ie:
A 250W landing light will draw aprox 9 amps on a 28V system and 18 amps on a 14V system. 

```
# landing light 250w @28v
electricsystem.connect(main_bus, e.Breaker.new("landing-lights",10.0), e.Light.new("landing-lights",9.0));
# Taxi light 100w @28v
electricsystem.connect(main_bus, e.Breaker.new("taxi-lights",5.0), e.Light.new("taxi-lights",3.6));
# 7w average led strobe light
electricsystem.connect(main_bus, e.Breaker.new("strobe-lights",1.0), e.Light.new("strobe-lights",0.25));
# 2x 15w led nav lights
electricsystem.connect(main_bus, e.Breaker.new("nav-lights",2.0), e.Light.new("nav-lights",1.1));

```
Annunciators connected to a common circuit breaker.
```
var annunciators_breaker = electricsystem.connect(main_bus, e.Breaker.new("annunciators",1.0));

electricsystem.connect(annunciators_breaker,e.Annunciator.new("battery-charge"));
electricsystem.connect(annunciators_breaker,e.Annunciator.new("oil-pressure-low"));
electricsystem.connect(annunciators_breaker,e.Annunciator.new("fuel-pressure-low"));
electricsystem.connect(annunciators_breaker,e.Annunciator.new("fuel-low"));
electricsystem.connect(annunciators_breaker,e.Annunciator.new("starter"));
electricsystem.connect(annunciators_breaker,e.Annunciator.new("flaps"));
```

Finally, enable the system to start the loop.
```
electricsystem.enable();
```
Or, if you are a puritan, wait for the fdm-initialized signal.
```
setlistener("sim/signals/fdm-initialized",func{
        electricsystem.enable();
    }
);
```

### Classes
See [Class Documentation](CLASSES.md)

