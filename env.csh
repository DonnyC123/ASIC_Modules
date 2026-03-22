#!/bin/csh

setenv CADENCE_BASE /vol/cadence2018/XCELIUM2109
setenv CDS_LIC_FILE /vol/cadence2018/license/share/license/license.2025
setenv VRST_HOME $CADENCE_BASE

if ( -f $CADENCE_BASE/env.csh ) then
    source $CADENCE_BASE/env.csh
    echo "Sourced Xcelium environment."
else
    echo "Error: Could not find env.csh at $CADENCE_BASE"
endif

setenv PATH ${CADENCE_BASE}/tools/bin:${CADENCE_BASE}/tools.lnx86/bin:$PATH

which xrun >& /dev/null
if ( $status == 0 ) then
    echo "Success: xrun is now available."
    xrun -version
else
    echo "Warning: xrun still not found in PATH."
endif

setenv GENUS_BASE /vol/cadence2018/GENUS211

setenv PATH ${GENUS_BASE}/tools/bin:${GENUS_BASE}/tools.lnx86/bin:$PATH

which genus >& /dev/null
if ( $status == 0 ) then
    echo "Success: genus is now available."
    genus -version
else
    echo "Warning: genus still not found in PATH."
endif

