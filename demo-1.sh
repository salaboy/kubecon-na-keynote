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



pe "cat arachnid-env.yaml"
pe "kubectl apply -f arachnid-env.yaml"
pe "kubectl get environments"

# show a prompt so as not to reveal our true nature after
# the demo has concluded
pe "kubectl get environments"


pe "vcluster connect arachnid-env --server https://localhost:8443 -- zsh"


