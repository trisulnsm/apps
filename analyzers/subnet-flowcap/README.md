# Subnet Flow cap

Remove flow storage cap for selected subnets 


## Flow Cap concept

In Trisul, user can specify a _Flow Volume Cutoff_. Only flows transmitting or receiving a total volume
greater than the _Flow Volume Cutoff_  will be stored in the database. Smaller flows will be discarded.
This is to prevent customer databases from exploding in size. 

See [Configuring Session Cutoff](https://www.trisul.org/docs/ug/flow/tuning.html#optimize_flow_handling)

With this app, you gain ability to use a volume cutoff but also allow selected subnets to store all flows. 

1. Set the Volume Cutoff Bytes option to 0 in Session Groups admin screen
2. Specify a list of subnets which will store all flows as shown below
3. Specify a new Volume Cutoff that will apply to all flows not matching the subnets listed 


## Installing 

To install this APP logon as admin, then select APP from _Web Admin > Manage > Apps._


Config Parameters
==============

The config settings you can customize on a per Probe basis

To supply your own custom settings, 

1. create a new config file named `trisulnsm_subnet-flowcap.lua` in the probe config directory
`/usr/local/var/lib/trisul-probe/domain0/probe0/context0/config` directory with the following
2. You only supply new values for parameters you want to replace 


````lua

return {
    -- which subnets
    Subnets =  {

        "209.85.175.96/30",
        "209.85.175.160/29",


    },

    -- volume cutoff
    VolumeCutOff =10000,
}

````


UPDATES
=======

````
1.0.0   Jul 5 2023     Initial release 
````


