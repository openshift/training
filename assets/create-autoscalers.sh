#!/bin/bash

export AUTOSCALER_JSON='{"apiVersion":"autoscaling.openshift.io/v1alpha1","kind":"MachineAutoscaler","metadata":{"name":"worker","namespace":"openshift-machine-api"},"spec":{"minReplicas":1,"maxReplicas":4,"scaleTargetRef":{"apiVersion":"machine.openshift.io/v1beta1","kind":"MachineSet","name":"worker"}}}'
export MACHINESETS=$(oc get machineset -n openshift-machine-api -o json | jq '.items[]|.metadata.name' -r )

for ms in $MACHINESETS
do
  NAME="autoscale-$ms"
  echo $AUTOSCALER_JSON | name=$NAME ms=$ms jq '.metadata.name=env["name"] | .spec.scaleTargetRef.name=env["ms"]' | oc create -f -
done
