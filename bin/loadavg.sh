#!/bin/bash
uptime | sed -e's/^.*load averages\{0,1\}: //g' -e's/, / /g'
