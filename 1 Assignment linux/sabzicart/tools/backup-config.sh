#!/bin/bash
# Copies the app config into the backups folder with today's date.
# Written by Kamran.
cp /home/abbasshafi/sabzicart/webapp/config/app.conf /home/abbasshafi/sabzicart/backups/app.conf-$(date +%F).bak
echo "Config backup done."
