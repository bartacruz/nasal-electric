###############################################################################
##
##  Electrical management for DR400-dauphin
##
##  Julio Santa Cruz (Barta)
##  
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Shorthand
var e = electric;

# Create new electric system that updates 10 times a second.
var electricsystem = e.System.new("dr400",0.1);

# According to DR400 Dauphing's POH
#                                                                    |      |
# Alternator -- [alternator breaker] -- (alternator-switch) -------- | Main |
#                                                                    |      |
# Battery -- | Starter | -- [battery breaker] -- (battery-switch) -- | Bus  |
# Ext Pwr -- |   Bus   | -- {starter}                                |      |
#                                                                    

### Starter and Main Bus
var starter_bus = e.Bus.new("starter-bus");
var main_bus = e.Bus.new("main-bus");

# Battery (12v 32a/h 240 CCA as per POH)
# connected to the starter bus to feed the starter directly.
# connected to the main bus from the starter bus via a 40A fuse and the battery switch.
# 
var battery = e.Battery.new("battery",12,32.0,cc_amps=240.0,charge_amps=2.0);
var battery_breaker = e.Breaker.new("battery",40.0);
var battery_switch = e.Switch.new("battery-switch","/controls/electric/battery-switch");

# System.connect support chaining.
electricsystem.connect(battery,starter_bus,battery_breaker, battery_switch, main_bus);

# Reverse connection for loading the battery...
electricsystem.connect(main_bus,battery_switch,battery_breaker,starter_bus,battery);

# External source
# Connected directly to the starter bus, but we add a switch to obey the prop
var external_source = e.Alternator.new("external",false,14.0,100.0);
electricsystem.connect(external_source,e.Switch.new("external-power","/controls/electric/external-power"),starter_bus);

# Alternator (12v 50a/h as per POH)
# Connected to the main bus via a 50A fuse and a switch
electricsystem.connect(
    e.Alternator.new("alternator","/engines/engine[0]/rpm",14.0,50.0),
    e.Breaker.new("alternator",50.0),
    e.Switch.new("alternator-switch","/controls/engines/engine[0]/master-alt",
    main_bus
);

### Engine related loads

# Starter engine draws 80A while cranking.
electricsystem.connect(
    starter_bus,
    e.Load.new("starter",80.0,"/controls/engines/engine[0]/starter_cmd")
);

# The ignition coil draws a max average of 4A at full RPM.
# Override to adjust the load with the RPMs of the engine, and connect it to 
# the main bus with a 10A breaker.
var coil = e.Load.new("ignition-coil",5,"/controls/engines/engine[0]/faults/spark-plugs-serviceable");
coil.get_amps = func(volts) {
    var rpms = getprop("/engines/engine[0]/rpm");
    var factor = rpms /2500;
    return me.amps * factor;
}
electricsystem.connect(
    main_bus, 
    e.Breaker.new("ignition-coil",10.0)
    coil
);

# carb heat is not electric, but somehow it needs an electric output set...
electricsystem.connect(
    main_bus, 
    e.Load.new("carb-heat",0.01,"/controls/anti-ice/engine/carb-heat")
);

# 4A Fuel pump with 5A breaker.
electricsystem.connect(
    main_bus,
    e.Breaker.new("fuel-pump",5.0),
    e.Load.new("fuel-pump",4.0,"/controls/fuel/tank/boost-pump")
);


### Exterior lights

# landing light 250w @12v => 18A with 25A breaker
electricsystem.add_light(main_bus,"landing-lights",18.0,25.0);
# Taxi light 100w @12v
electricsystem.add_light(main_bus,"taxi-lights",8.3,10.0);
# 7w average led strobe light
electricsystem.add_light(main_bus,"strobe-lights",0.6,1.0);
# 2x 15w led nav lights
electricsystem.add_light(main_bus,"nav-lights",2.5,5.0);

### Annunciators

# All annunciator lights are connected to a single 1A breaker.
var annunciators_breaker = electricsystem.connect(main_bus, e.Breaker.new("annunciators",1.0));

electricsystem.add_annunciator(annunciators_breaker,"battery-charge");
electricsystem.add_annunciator(annunciators_breaker,"oil-pressure-low");
electricsystem.add_annunciator(annunciators_breaker,"fuel-pressure-low");
electricsystem.add_annunciator(annunciators_breaker,"fuel-low");
electricsystem.add_annunciator(annunciators_breaker,"starter");
electricsystem.add_annunciator(annunciators_breaker,"flaps");

# Instrument lights (led 3w each)
electricsystem.add_light(main_bus,"instrument-lights[0]",0.11);
electricsystem.add_light(main_bus,"instrument-lights[1]",0.11);
electricsystem.add_light(main_bus,"instrument-lights[2]",0.11);

# Flood Light
electricsystem.add_light(main_bus,"flood-light-left",0.3);
electricsystem.add_light(main_bus,"flood-light-right",0.3);

### Avionics

# Avionics bus - connected to main bus.
var avionics_switch = e.Switch.new("master-avionics","controls/switches/master-avionics" );
var avionics_bus = e.Bus.new("avionics-bus");
electricsystem.connect(main_bus,avionics_switch,avionics_bus);

electricsystem.connect(avionics_bus, e.Load.new("turn-coordinator",1.0,"controls/switches/master-avionics"));
electricsystem.add_instrument(avionics_bus,"transponder",3.0,10.0);
electricsystem.add_instrument(avionics_bus,"adf",1.0,2.0);
electricsystem.add_instrument(avionics_bus,"gps",0.5);
# Nav and comm shares a breaker.
var radio_breaker = electricsystem.connect(avionics_bus, e.Breaker.new("radio",10.0));
electricsystem.connect(radio_breaker, e.Instrument.new("comm[0]",0.5));
electricsystem.connect(radio_breaker, e.Instrument.new("nav[0]",0.5));

setlistener("sim/signals/fdm-initialized",func{
    electricsystem.enable();
});

print("DR400 electrical system loaded");
