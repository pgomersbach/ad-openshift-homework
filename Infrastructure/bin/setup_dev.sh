#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

# To be Implemented by Student

#config permission
oc policy add-role-to-user admin system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-dev

oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-dev

oc policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-dev

oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-dev

oc new-app -e MONGODB_USER=mongodb -e MONGODB_PASSWORD=mongodb -e MONGODB_DATABASE=parks -e MONGODB_ADMIN_PASSWORD=mongodb --name=mongodb registry.access.redhat.com/rhscl/mongodb-34-rhel7:latest -n ${GUID}-parks-dev

#create buildconfig
oc new-build --binary=true --name="mlparks" jboss-eap70-openshift:1.7 -n ${GUID}-parks-dev

oc new-build --binary=true --name="nationalparks" redhat-openjdk18-openshift:1.2 -n ${GUID}-parks-dev

oc new-build --binary=true --name="parksmap" redhat-openjdk18-openshift:1.2 -n ${GUID}-parks-dev

#create configmap
oc create configmap mlparks-config --from-env-file=./Infrastructure/templates/MLBParks-dev.env -n ${GUID}-parks-dev

oc create configmap nationalparks-config --from-env-file=./Infrastructure/templates/NationalParks-dev.env -n ${GUID}-parks-dev

oc create configmap parksmap-config --from-env-file=./Infrastructure/templates/ParksMap-dev.env -n ${GUID}-parks-dev

#create app
oc new-app ${GUID}-parks-dev/mlparks:0.0-0 --name=mlparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev

oc new-app ${GUID}-parks-dev/nationalparks:0.0-0 --name=nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev

oc new-app ${GUID}-parks-dev/parksmap:0.0-0 --name=parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev

#remove triggers
oc set triggers dc/mlparks --remove-all -n ${GUID}-parks-dev

oc set triggers dc/nationalparks --remove-all -n ${GUID}-parks-dev

oc set triggers dc/parksmap --remove-all -n ${GUID}-parks-dev

#set ent for dc
oc set env dc/mlparks --from=configmap/mlparks-config -n ${GUID}-parks-dev

oc set env dc/nationalparks --from=configmap/nationalparks-config -n ${GUID}-parks-dev

oc set env dc/parksmap --from=configmap/parksmap-config -n ${GUID}-parks-dev

oc set probe dc/parksmap --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-dev
oc set probe dc/parksmap --readiness --failure-threshold 5 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

oc set probe dc/mlparks --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-dev
oc set probe dc/mlparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

oc set probe dc/nationalparks --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-dev
oc set probe dc/nationalparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

oc set deployment-hook dc/nationalparks --post -c nationalparks --failure-policy=abort -- curl http://127.0.0.1:8080/ws/data/load/

#expose svcs
oc expose dc mlparks --port 8080 -n ${GUID}-parks-dev

oc expose dc nationalparks --port 8080 -n ${GUID}-parks-dev

oc expose dc parksmap --port 8080 -n ${GUID}-parks-dev

oc expose svc mlparks -n ${GUID}-parks-dev --labels="type=parksmap-backend"

oc expose svc nationalparks -n ${GUID}-parks-dev --labels="type=parksmap-backend"

oc expose svc parksmap -n ${GUID}-parks-dev