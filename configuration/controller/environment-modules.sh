#!/bin/bash

# Environment modules setup

if flag_is_unset CHROOT_INSTALL ; then
    
    echo_info 'Creating the shared modules directories'
    
    # Contents of the modulefiles directory:
    # /trinity/shared/
    # `-- modulefiles
    #     |-- cv-advanced       advanced CV modules, not available by default
    #     ¦-- cv-standard       standard CV modules, available by default
    #     |-- local             site-local modules, available by default
    #      -- modulegroups      modulefiles to load groups (advanced, local, etc)
    
    mkdir -p "${TRIX_SHARED}/modulefiles"
    mkdir -p "${TRIX_SHARED}/modulefiles/modulegroups"
    mkdir -p "${TRIX_SHARED}/modulefiles/cv-standard"
    mkdir -p "${TRIX_SHARED}/modulefiles/cv-advanced"
    mkdir -p "${TRIX_SHARED}/modulefiles/local"
    
    
    echo_info 'Adding the group modulefiles'
    
    cp "${POST_FILEDIR}/cv-advanced" "${TRIX_SHARED}/modulefiles/modulegroups"
    
    
    echo_info 'Adjusting the trinityX installation path'
    
    sed -i 's#TRIX_ROOT#'"$TRIX_ROOT"'#g' "${TRIX_SHARED}/modulefiles/modulegroups/"*
fi


echo_info 'Adding the group path to the default configuration'

dest='/usr/share/Modules/init/.modulespath'

append_line "$dest" "${TRIX_SHARED}/modulefiles/modulegroups"
append_line "$dest" "${TRIX_SHARED}/modulefiles/cv-standard"
append_line "$dest" "${TRIX_SHARED}/modulefiles/local"

