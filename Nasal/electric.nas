systems ={};

var charge_battery_cb= func(node) {
    var s = split("/",node.getPath());
    var bn = s[-2];
    var charge_percent = node.getDoubleValue();
    if (charge_percent < 0 or charge_percent > 1) return;
    foreach (var system; values(systems)) {
        if (find(system.path,node.getPath()) < 0) continue;
        foreach(var source;system.sources){
            if (source.is_instance(Battery) and source.name == bn){
                printf("setting charge of %s from %f to %f", source.id(),source.charge_percent,charge_percent);
                source.set_charge_percent(charge_percent);
            }
        }
    }
};

var setpropr = func(dec,path,val) {
    var mult = math.pow(10,dec);
    var val_r = int(val * mult) / mult;
    setprop(path,val_r);
}


##
# Base class for all electric-related classes.
# 
var Class= {
    class_name: "Class",

    ##
    # Creates and returns a new Class instance, calling init and publish.
    # Subclasses shouldn't use Class.new. See #init
    new: func(name) {
        var obj = {parents:[Class]};
        obj.init(name);
        obj.publish();
        return obj;
    },
    ##
    # Handy function for initializing without generating a new object (avoid calling new())
    # Subclasses should call
    #   me.super(Class,"init",name);
    # inside their init func.
    init: func(name) {
        me.name = name;
        me.sources = [];
        me.loads = [];
        me.voltage = 0;
        me.current = 0;
        me.path = nil; # sublcasses must declare.
        me.system = nil;
    },
    ##
    # Returns the id of this instance in the form class-name:name
    # ie: Source:alternator, Bus:main-bus, etc.
    #
    id: func {
        return me.class_name~":"~me.name;
    },
    add_source: func(source){
        if (!contains(me.sources,source))
            append(me.sources,source);
        return source;
    },
    ##
    # Returns the sources of this object, sorted by bigger voltage.
    #
    get_sources: func {
        return sort (me.sources, func (a,b) a.get_volts() < b.get_volts());
    },
    add_load: func(load) {
        append(me.loads,load);
        return load;
    },
    ##
    # Gets a prop relative to this object's path.
    #
    get_prop: func(prop) { 
        if (me.path)
            return getprop(me.path ~ me.name ~ "/" ~ prop);
        return nil;
    },
    ##
    # Sets a prop's value relative to this object's path.
    #
    set_prop: func(prop,val) { 
        if (me.path)
            setprop(me.path ~ me.name ~ "/" ~ prop,val);
    },
    ##
    # Checks if this object is instance of a Class.
    # class: the class OBJECT (not it's name)
    # example:
    # obj.is_instance(electric.Bus)
    #
    is_instance: func(class) {
        var find_parent = func(o,class){                
            if (o.class_name == class.class_name) return true;
            if (contains(o,'parents') and size(o.parents)){
                foreach (var p; o.parents) {
                    return find_parent(p,class);
                }
            }
            return false;
        }
        return find_parent(me,class);
    },
    ##
    # Calls a method in a subclass of this object.
    # class: the class OBJECT (not it's name)
    # method: a string containing the method's name.
    # Any other arguments in the call will be passed as arguments
    # to the method.
    # The method will be called with this object as namespace (me)
    #
    #  obj.super(electric.Class,"init",name);
    # 
    super: func(class,method) {
        var fun = sprintf("%s.%s",class.class_name,method);
        var fn = compile(fun);
        var ret = call(fn(),arg,me);
        return ret;
    },

    reset: func {
        me.voltage=0;
        me.current=0;
    },
    publish: func(obj=nil) {
        obj = obj or me;
        me.set_prop("voltage",me.voltage);
        me.set_prop("current",me.current);
    },
    str: func(){
        return sprintf("[%s %.4fV %.4fA]",me.id(),me.voltage,me.current);
    },
};

##
# Helper functions
#
Class.ids = func(v) {
    var ret = [];
    foreach(var c;v) append(ret,c.id());
    return debug.string(ret);
}
Class.labels=func(v) {
    var ret = [];
    foreach(var c;v) append(ret,c.str());
    return debug.string(ret);
}
Class.names = func(v) {
    var ret = [];
    foreach(var c;v) append(ret,c.name);
    return ret;
}
Class.names_str = func(v) {
    return debug.string(Class.names(v));
}

##
# 
# Base class for all power sources. Batteries, Alternators, and so.
# It's mainly used for identification (using is_instance)
#
var Source = {
    class_name: "Source",
    parents: [Class],
    new: func(name) {
        var obj= {parents:[Source]};
        obj.init(name);
        return obj;
    },
    init: func(name) {
        me.super(Class,"init",name);
        me.path= "/systems/electrical/sources/";
    },
};

##
# A load is anything that draws current from the system.
# Lights, instruments, pumps, etc.
# It'll publish the voltage under /systems/electrical/outputs/[name]
# 
var Load = {
    parents: [Class],
    class_name: "Load",
    
    new: func (name, amps, switch) {
        var obj = {parents : [Load]};
        obj.init(name,amps,switch);
        obj.publish();
        return obj;
    },

    init:func (name, amps, switch) {
        me.super(Class,"init",name);
        me.switch = switch;
        me.amps = amps;
        me.output = "/systems/electrical/outputs/";
        me.path = "/systems/electrical/loads/";
    },

    publish: func{
        me.super(Class, "publish");
        if (me.output){
            setpropr(5,me.output~me.name, me.voltage);
        }

    },
    
    ##
    # Returns the voltage output of this load, given an input voltage.
    # Can be overwritten by subclasses or instances to accomodate variable loads.
    # ie: panel lights, ignition coil, etc.
    get_volts: func(volts) {
        # switch could be a potentiometer (ie: a light dimmer)
        var switch = getprop(me.switch);
        if (switch == nil or switch == false) {
            switch = 0;
        }
        return  switch * volts;
    },
    ##
    # Return the nominal current of this load.
    # Can be overwritten by subclasses or instances to accomodate variable loads.
    # ie: panel lights, ignition coil, etc.
    get_amps: func(volts=nil) {
        return me.amps;
    },

    ##
    # Main load function.
    # Returns the current consumption (in Amps/h) of this load, given an input 
    # voltage and a delta time.
    # Calls get_volts and get_amps to calculate.
    #
    get_load: func(volts,dt) {
        var v = me.get_volts(volts);
        var a = me.get_amps(v);
        if (v and a ) {
            me.voltage = v;
            me.current = a;
        } else {
            me.voltage = 0.0;
            me.current = 0.0;
        }
        #printf("%s %s volts=%s voltage=%s current=%s", me.class_name,me.name,volts,me.voltage,me.current);
        return me.current;
    }
};

##
# Load specific implementation to represent a Light witha switch.
# By default, it'll use the switch at "/controls/lighting/[name]"
var Light = {
    parents: [Load],
    class_name:"Light",
    new: func (name, amps, switch=nil) {
        var obj = {parents : [Light]};
        obj.init(name,amps,switch);
        obj.publish();
        return obj;
    },
    init: func(name,amps,switch=nil) {
        switch = switch or "/controls/lighting/" ~ name;
        me.super(Load,"init",name,amps,switch);
    },
};

##
# Light specific implementation to represent a 1W panel annunciator.
# By default, it'll use the switch at "/instrumentation/annunciators/[name]"
# 
var Annunciator = {
    parents: [Light],
    class_name:"Annunciator",
    DEFAULT_AMPS: 0.09, # Aprox 1w@12v
    DEFAULT_PATH: "/instrumentation/annunciators/",
    new: func (name, amps=nil, switch=nil) {
        var obj = {parents : [Annunciator]};
        obj.init(name,amps,switch);
        obj.publish();
        return obj;
    },
    init: func (name, amps=nil, switch=nil) {
        amps = amps or Annunciator.DEFAULT_AMPS;
        switch = switch or Annunciator.DEFAULT_PATH ~ name;
        me.super(Light,"init",name,amps,switch);
    },
};

##
# Load specific implementation to represent an instrument with a switch.
# By default, it'll use the switch at "/instrumentation/[name]/power-btn"
var Instrument = {
    parents: [Load],
    class_name:"Instrument",
    new: func (name, amps, switch=nil) {
        var obj = {parents : [Instrument]};
        obj.init(name,amps,switch);
        obj.publish();
        return obj;
    },
    init: func(name,amps,switch=nil) {
        switch = switch or "/instrumentation/" ~ name ~ "/power-btn";
        me.super(Load,"init",name,amps,switch);
    },
};

##
# Base class for connecting elements, that draws no (significant) load from the system.
# It will pass on the calls to `get_load` and `apply_load` to the loads and sources
# connected to it, returning the max voltage of its sources and the sum of the
# currents of its loads, respectively.
#
var Wire = {
    parents: [Class],
    class_name: "Wire",
    new: func(name) {
        var obj = { parents: [Wire]};
        obj.init(name);
        return obj;
    },
 
    #
    # Between 0-1
    #
    get_factor: func(volts) {
        return 1;
    },

    ##
    # Calls get_load to all it's loads and returns the sum of the current draw.
    # Ignores the loads that have a voltage greater than us.
    #
    get_load: func(volts,dt) {
        var current=0;
        volts = volts * me.get_factor(volts);
        me.voltage = volts;
        foreach(var load; me.loads) {
            # Apply current to load only if our voltage is greater.
            if (load.voltage < volts) 
                current += load.get_load(volts,dt);
            # else
            #     printf("Ignoring bigger load %s < %s",me.str(), load.str());
        }
        #printf("\t%s %s get_load(%s) = %s | %s", me.class_name,me.name,volts,current,me.names_str(me.loads));
        me.current = current;
        
        return current;
    },
    get_volts: func {
        # var sources = sort (bus.sources, func (a,b) a.get_volts() < b.get_volts());
        # return sources[0].get_volts();
        # Mmmmm....
        return me.voltage;
    },
    apply_load: func(load,dt) {
        if (me.get_factor(me.voltage) > 0)
            return me.get_sources()[0].apply_load(load,dt);
        return 0;
    }
};

##
# A wire that publishes it's output to /systems/electrical/outputs/
# unless otherwise specified.
# 
var Bus = {
    parents: [Wire],
    class_name: "Bus",
    new: func(name, output=nil){
        var obj = {parents : [Bus]};
        obj.init(name,output);
        obj.publish();
        return obj;
    },
    init: func(name,output=nil) {
        me.super(Wire,"init",name);
        me.output = output or "/systems/electrical/outputs/";
    },
    publish: func{
        me.super(Wire,"publish");
        if (me.output){
            setpropr(5,me.output~me.name, me.voltage);
        }
    },
};

##
# A wire with conditional conductivity.
# switch: path to a prop that can take values from 0 to 1.
#         The value of switch will be used to factorize conductivity.
var Switch = {
    parents: [Wire],
    class_name: "Switch",

    new: func(name,switch=nil) {
        var obj = {parents : [Switch]};
        obj.init(name,switch);
        obj.publish();
        return obj;
    },
    init: func(name,switch=nil){
        me.super(Wire,"init",name);
        me.switch= switch or "/controls/switches/" ~ name;
    },
    get_factor: func(volts) {
        var switch = me.switch ? getprop(me.switch) : 1;
        return switch;
    },
    
};

##
# A Wire that can burn/pop if current exceed its rated amps.
# By default it'l use /controls/circuit-breakers/[name] prop
# to get/set the breaker's state.
#
var Breaker = {
    parents: [Wire],
    class_name: "Breaker",
    new: func(name,amps, control="/controls/circuit-breakers/") {
        var obj = {parents: [Breaker]};
        obj.init(name,amps, control);
        obj.publish();
        return obj;
    },
    init: func(name,amps, control) {
        me.super(Wire,"init",name);
        me.amps = amps;
        me.state = control~name;
        me.set_state(1);
    },
    
    get_state: func return getprop(me.state),
    set_state: func(state) setprop(me.state,state),

    ##
    # Override
    get_factor: func(volts) {
        return me.get_state();
    },

    ##
    # Override of Wire.get_load to check/set the breakers state
    #
    get_load: func(volts,dt){
        if (!me.get_state()){
            me.current =0;
            me.voltage = 0;
        } else {
            me.current = me.super(Wire,"get_load",volts,dt);
            #printf("Breaker %s current=%s amps=%s", me.name,me.current,me.amps);
            if (me.current > me.amps *1.1) {
                print(sprintf("### Circuit-breaker %s popped! %f > %f", me.name, me.current, me.amps ));
                me.set_state(1);
            }
        }
        return me.current;
    },
};

##
# Battery model class.
#
var Battery = {
    class_name: "Battery",
    parents: [Source],

    ##
    # volts: rated volts (normally, 12 or 24)
    # amps: amps/hour 
    # cc_amps: cold crank amps
    # charge_percent: between 0 and 1.
    #
    # TODO: implement cca discharge and recovery.
    #
    new: func (name, volts,amps,cc_amps, charge_amps=nil, charge_percent=nil) {
        var obj = { parents : [Battery]};
        obj.init(name, volts,amps,cc_amps, charge_amps, charge_percent);
        obj.publish();
        return obj;
    },
    init: func(name, volts,amps,cc_amps, charge_amps=nil, charge_percent=0){
        me.super(Source,"init",name);
        me.volts = volts;
        me.amps = amps;
        me.cc_amps = cc_amps;
        me.charge_amps = charge_amps or amps*0.3;
        me.charge_percent = charge_percent or me.get_prop("charge-percent") or 1.0;
        # Listener to update the charge of the battery from outside the system.
        # Useful for save/restore purposes or a reset option menu.
        me.listener = setlistener(me.path ~ me.name~"/set-charge-percent", charge_battery_cb ,0,0);
    },
    publish: func() {
        me.super(Class,"publish");
        me.set_prop("charge-percent",me.charge_percent);    
        me.set_prop("amps", me.get_amps());
    },
    
    ##
    # Return output volts based on percent charged.  Currently based on a simple
    # polynomial percent charge vs. volts function.
    #
    get_volts: func {
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        return me.volts * factor;
    },
    ##
    # Get available amps/h
    #
    get_amps: func {
        return me.amps * me.charge_percent;
    },
    ##
    # Get available CCA
    #
    get_cc_amps: func {
        return me.cc_amps * me.charge_percent;
    },
    ##
    # Discharge the battery
    #
    apply_load: func(amps, dt) {
        if (getprop("/sim/freeze/replay-state"))
            return me.get_cc_amps();
        var load_amps = math.min(amps,me.get_cc_amps());
        var amps_used = load_amps * dt / 3600.0;
        var percent_used = amps_used / me.amps;
        me.charge_percent = std.max(0.0, me.charge_percent - percent_used);
        me.voltage = me.get_volts();
        me.current = load_amps;
        return  amps - me.get_cc_amps();
    },
    ##
    # Charge the battery
    # Acts as a Load to draw current from the system if the system voltage
    # is higher than his.
    #
    get_load: func(volts,dt) {
        if (volts <= me.get_volts()) {
            return 0;
        }
        # TODO: factorize charge_amps using voltage difference with source.
        var amps_used = me.charge_amps * dt / 3600.0;
        var percent_used = amps_used / me.amps;
        me.charge_percent = std.min(me.charge_percent + percent_used, 1.0);
        me.voltage = me.get_volts();
        me.current = -1* me.charge_amps;
        return me.charge_amps;
    },

    ##
    # Updates this battery's charge percent.
    # 
    set_charge_percent: func(charge_percent) {
        if (me.system.loop.enabled) {
            # avoid our value being overwritten by the update process.
            me.system.loop.disable();
            me.charge_percent = charge_percent;
            me.system.loop.enable();
        } else {
            me.charge_percent = charge_percent;
        }
    }
};

##
# Alternator model class.
#
var Alternator = {
    parents: [Source],
    class_name: "Alternator",
    new: func (name,source,volts,amps,rpm_threshold=800){    
        var obj = {parents : [Alternator]};
        obj.init(name,source,volts,amps,rpm_threshold);
        return obj;
    },
    init: func(name,source,volts,amps,rpm_threshold=800) {
        me.super(Source,"init",name);
        me.rpm_source= source;
        me.rpm_threshold= rpm_threshold;
        me.volts= volts;
        me.amps= amps;        
        if (me.rpm_source) {
            setprop( me.rpm_source, 0.0 );
        }
    },
    ##
    # Scale alternator output for rpms < 800.  For rpms >= 800
    # give full output.  This is just a WAG, and probably not how
    # it really works but I'm keeping things "simple" to start.   
    get_factor: func {
        if (! me.rpm_source) {
            # No factor. Could be an external source.
            return 1.0;
        }
        var rpm = getprop( me.rpm_source );
        var factor = rpm / me.rpm_threshold;
        if ( factor > 1.0 ) {
            factor = 1.0;
        }
        return factor;
    },
    ##
    # Return output volts based on rpm
    #
    get_volts: func {
        return me.volts * me.get_factor();
    },

    ##
    # Return output amps available based on rpm.
    #
    get_amps: func {
        return me.amps * me.get_factor();
    },
    apply_load: func( amps, dt ) {  
        # print( "alternator amps = ", me.amps * factor );
        var available_amps = me.get_amps();
        me.current = math.min(available_amps,amps);
        me.voltage = me.get_volts();
        return amps - available_amps;
    },
};

##
# Initializes a new electric system.
var System = {
    parents: [Class],
    class_name: "System",
    new: func(name, update_period=0.1,path="/systems/electrical/") {
        var obj = {parents: [System]};
        obj.init(name, update_period,path);
        obj.publish();
        return obj;
    },
    init: func(name, update_period,path) {
        me.super(Class,"init",name);
        me.path = path;
        me.buses = [];
        me.loads = {};
        
        me.loop = updateloop.UpdateLoop.new(components: [me], update_period: update_period, enable: 0);
        systems[name] = me;
    },
    publish: func{
        me.super(Class,"publish");
        # Backwards compatibility
        setprop(me.path~"volts", me.voltage);
        setprop(me.path~"amps", me.current);
    },
    ###
    # Connects 2 or more elements
    # If there's more than 2, it'll create a chain of source/loads for each pair of
    # consecutive elements.
    # ie:
    # To create a 15A landing light and hook it to the main bus via a 20A breaker:
    #   var main_bus = electric.Wire.new("main", etc-);
    #   var breaker = electric.Breaker.new("landing-light",20);
    #   var light = electric.Light.new("landing-light",15);
    #
    # Main bus is the source of the breaker, and the breaker is the load of the bus.
    #   electric.system.connect(main_bus, breaker);
    #
    # The breaker is the source of the light, and the light is the load of the breaker.
    #   electric.system.connect(breaker,light);
    # 
    # it's the same as:
    # electric.system.connect(main_bus, breaker , light );
    # 
    ###
    connect: func {
        var load = nil;
        var source = nil;
        for (var i=0; i< size(arg)-1 ; i=i+1) {
            source = arg[i] or source;
            load = arg[i+1];

            if (!source or ! load) continue;

            # add a reference to the system they are connected (myself)
            source.system = me;
            load.system = me;

            source.add_load(load);
            load.add_source(source);
            if (source.is_instance(Source)) {
                me.add_source(source); 
            }  
            me.loads[load.id()]= load;
        }
        return load;
    },

    add_light: func(source, name, amps, breaker_amps=0) {
        var light = Light.new(name,amps);
        if (breaker_amps){
            me.connect(source,Breaker.new(name,breaker_amps),light);
        } else {
            me.connect(source,light);
        }
    },
    add_instrument: func(source, name, amps, breaker_amps=0) {
        var instrument = Instrument.new(name,amps);
        if (breaker_amps){
            me.connect(source,Breaker.new(name,breaker_amps),instrument);
        } else {
            me.connect(source,instrument);
        }
    },
    
    # UpdateLoop methods
    enable: func {
        me.loop.reset();
        me.loop.enable();
        print("Electrical system enabled");
    },
    disable: func {
        me.loop.disable();
    },
    reset: func {},

    update: func(dt){
        var start = systime();
        var serviceable = getprop(me.path ~ "serviceable");
        foreach(var load; values(me.loads)){
            load.reset();
        }
        var load_buses = [];
        foreach (var source; me.get_sources()) {
            source.reset();
            if (source.get_volts() <=0 ) continue;
            foreach (var load;source.loads){
                if (!contains(load_buses,load)) append(load_buses,load);
            }
        }
        #print("load_buses ", Class.labels(load_buses));
        foreach (var bus; load_buses){
            if (bus.voltage) {
                # Already visited
                continue;
            }
            # Bus sources sorted by volts.
            var sources = bus.get_sources();
            var sources_volts = sources[0].get_volts();

            # Traverse the bus loads gathering current.
            var load_amps = bus.get_load(sources_volts,dt);
            #printf("%s (from %s) %sV %sA s=%s",bus.str(), sources[0].str(), sources_volts, load_amps, Class.ids(sources));
            # Draw the current from the sources.
            var remaining_amps=load_amps;
            foreach (var source; sources) {
                if (source.get_volts() > 0) {
                        # apply load to the source and get remaining amps.
                        # remaing > 0 means it didn't fulfill the load.
                        # remaining < 0 means it has power left to charge batteries.

                        remaining_amps= source.apply_load( remaining_amps, dt);
                        if (remaining_amps <=0) break;
                } else {
                    break;
                }
            }
        }
        foreach(var load; values(me.loads)){
            load.publish();
        }
        foreach(var source; me.sources){
            source.publish();
        }
        me.voltage = 0;
        me.current = 0;
        foreach(var bus;load_buses){
            me.current +=bus.current;
            me.voltage = math.max(me.voltage,bus.voltage);
        }
        me.publish();
        var end = systime();
        #setprop(me.path~"/update",end-start);
    }
};


