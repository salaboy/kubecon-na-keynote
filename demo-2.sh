#!/usr/bin/env bash

########################
# include the magic
########################
. demo-lib/demo-magic.sh


########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
# TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#

# hide the evidence
clear

pe "cd functions"
pe "mkdir spiderize && cd spiderize"
pe "func create -r https://github.com/salaboy/func -l go -t spiders"
pe "ls -al"
pe "func deploy -v --registry docker.io/salaboy --push=false"

