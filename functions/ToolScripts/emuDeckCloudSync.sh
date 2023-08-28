#!/bin/bash
cloud_sync_path="$toolsPath/rclone"
cloud_sync_bin="$cloud_sync_path/rclone"
cloud_sync_config="$cloud_sync_path/rclone.conf"

cloud_sync_install(){	
  {
    
    local cloud_sync_provider=$1  
    setSetting cloud_sync_provider "$cloud_sync_provider" > /dev/null 
    setSetting cloud_sync_status "true" > /dev/null 
    rm -rf "$HOME/.config/systemd/user/EmuDeckCloudSync.service" > /dev/null 
    
    cloud_sync_createService
    
    if [ ! -f $cloud_sync_bin ]; then
      mkdir -p "$cloud_sync_path"/tmp > /dev/null
      curl -L "$(getReleaseURLGH "rclone/rclone" "linux-amd64.zip")" --output "$cloud_sync_path/tmp/rclone.temp" && mv "$cloud_sync_path/tmp/rclone.temp" "$cloud_sync_path/tmp/rclone.zip" > /dev/null 
      
      unzip -o "$cloud_sync_path/tmp/rclone.zip" -d "$cloud_sync_path/tmp/" && rm "$cloud_sync_path/tmp/rclone.zip" > /dev/null 
      mv "$cloud_sync_path"/tmp/* "$cloud_sync_path/tmp/rclone"  > /dev/null  #don't quote the *
      mv  "$cloud_sync_path/tmp/rclone/rclone" "$cloud_sync_bin" > /dev/null 
      rm -rf "$cloud_sync_path/tmp" > /dev/null 
      chmod +x "$cloud_sync_bin" > /dev/null 
    fi
    
    
  } > /dev/null
}

cloud_sync_toggle(){
  local status=$1  
  setSetting cloud_sync_status $status > /dev/null 
}	

cloud_sync_config(){	
 
  kill -15 $(pidof rclone)
  local cloud_sync_provider=$1  
   cp "$EMUDECKGIT/configs/rclone/rclone.conf" "$cloud_sync_config"
  cloud_sync_stopService
  cloud_sync_setup_providers

  
}

cloud_sync_setup_providers(){
  
    if [ $cloud_sync_provider == "Emudeck-NextCloud" ]; then
    
      local url
      local username
      local password
    
      NCInput=$(zenity --forms \
          --title="Nextcloud Sign in" \
          --text="Please enter your Nextcloud information here. URL is your webdav url. Use HTTP:// or HTTPS:// please." \
          --width=300 \
          --add-entry="URL: " \
          --add-entry="Username: " \
          --add-password="Password: " \
          --separator="," 2>/dev/null)
          ans=$?
      if [ $ans -eq 0 ]; then
        echo "Nextcloud Login"
        url="$(echo "$NCInput" | awk -F "," '{print $1}')"
        username="$(echo "$NCInput" | awk -F "," '{print $2}')"
        password="$(echo "$NCInput" | awk -F "," '{print $3}')"
        
        $cloud_sync_bin config update "$cloud_sync_provider" vendor="nextcloud" url=$url  user=$username pass="$($cloud_sync_bin obscure $password)"
      else
        echo "Cancel Nextcloud Login" 
      fi
    elif [ $cloud_sync_provider == "Emudeck-SFTP" ]; then
    
      NCInput=$(zenity --forms \
          --title="SFTP Sign in" \
          --text="Please enter your SFTP information here." \
          --width=300 \
          --add-entry="Host: " \
          --add-entry="Username: " \
          --add-password="Password: " \
          --add-entry="Port: " \
          --separator="," 2>/dev/null)
          ans=$?
      if [ $ans -eq 0 ]; then
        echo "SFTP Login"
        host="$(echo "$NCInput" | awk -F "," '{print $1}')"
        username="$(echo "$NCInput" | awk -F "," '{print $2}')"
        password="$(echo "$NCInput" | awk -F "," '{print $3}')"
        port="$(echo "$NCInput" | awk -F "," '{print $4}')"
        
        $cloud_sync_bin config update "$cloud_sync_provider" host=$host user=$username port=$port pass="$($cloud_sync_bin obscure $password)"
      else
        echo "Cancel SFTP Login" 
      fi
    
    
    elif [ $cloud_sync_provider == "Emudeck-SMB" ]; then
    
      NCInput=$(zenity --forms \
          --title="SMB Sign in" \
          --text="Please enter your SMB information here." \
          --width=300 \
          --add-entry="Host: " \
          --add-entry="Username: " \
          --add-password="Password: " \
          --separator="," 2>/dev/null)
          ans=$?
      if [ $ans -eq 0 ]; then
        echo "SMB Login"
        host="$(echo "$NCInput" | awk -F "," '{print $1}')"
        username="$(echo "$NCInput" | awk -F "," '{print $2}')"
        password="$(echo "$NCInput" | awk -F "," '{print $3}')"
        
        $cloud_sync_bin config update "$cloud_sync_provider" host=$host user=$username pass="$($cloud_sync_bin obscure $password)"
      else
        echo "Cancel SMB Login" 
      fi
      
    else
      $cloud_sync_bin config update "$cloud_sync_provider" && echo "true"
    fi
}

 cloud_sync_generate_code(){
   #Lets search for that token
   while read line
   do
      if [[ "$line" == *"[Emudeck"* ]]
      then
        section=$line
      elif [[ "$line" == *"token = "* ]]; then
        token=$line
        break     
      fi
   
   done < $cloud_sync_config
   
   replace_with=""
   
   # Cleanup
   token=${token/"token = "/$replace_with}
   token=$(echo "$token" | sed "s/\"/'/g")
   section=$(echo "$section" | sed 's/[][]//g; s/"//g')  
   
   json='{"section":"'"$section"'","token":"'"$token"'"}'
   
   #json=$token
   
   response=$(curl --request POST --url "https://patreon.emudeck.com/hastebin.php" --header "content-type: #application/x-www-form-urlencoded" --data-urlencode "data=${json}")
   text="$(printf "<b>CloudSync Configured!</b>\nIf you want to set CloudSync on another EmuDeck installation you need to use #this code:\n\n<b>${response}</b>")"
    
    zenity --info --width=300 \
   --text="${text}" 2>/dev/null
   
   clean_response=$(echo -n "$response" | tr -d '\n')
 }

 cloud_sync_config_with_code(){	
   local code=$1
   if [ $code ]; then
     cloud_sync_stopService
     
     json=$(curl -s "https://patreon.emudeck.com/hastebin.php?code=$code")     
     json_object=$(echo $json | jq .)
     
     section=$(echo $json | jq .section)
     token=$(echo $json | jq .token)
    
      # Cleanup
      token=$(echo "$token" | sed "s/\"//g")
      token=$(echo "$token" | sed "s/'/\"/g")            
      section=$(echo "$section" | sed 's/[][]//g; s/"//g')     
      
     cp "$EMUDECKGIT/configs/rclone/rclone.conf" "$cloud_sync_config"
     
     iniFieldUpdate "$cloud_sync_config" "$section" "token" "$token"     
     
     #Bad Temp fix:
     
     sed -i "s/token =/''/g" $cloud_sync_config
     sed -i 's/  /token = /g' $cloud_sync_config
     
   else
     exit
   fi
   
 }

cloud_sync_install_and_config(){	
    local cloud_sync_provider=$1
    #We force Chrome to be used as the default
    browser=$(xdg-settings get default-web-browser)
    
    if [ $browser != 'com.google.Chrome.desktop' ];then
      flatpak install flathub com.google.Chrome -y
      xdg-settings set default-web-browser com.google.Chrome.desktop
    fi
    
    if [ ! -f $cloud_sync_bin ]; then
      cloud_sync_install $cloud_sync_provider
    fi
    
    cloud_sync_config $cloud_sync_provider
    
    #We get the previous default browser back
    if [ $browser != 'com.google.Chrome.desktop' ];then
      xdg-settings set default-web-browser $browser
    fi
}

cloud_sync_install_and_config_with_code(){	
    local cloud_sync_provider=$1    
    code=$(zenity --entry --text="Please enter your SaveSync code")
    cloud_sync_install $cloud_sync_provider
    cloud_sync_config_with_code $code
}


cloud_sync_uninstall(){
  setSetting cloud_sync_status "false" > /dev/null 
  rm -rf $cloud_sync_bin && rm -rf $cloud_sync_config && echo "true"
}


cloud_sync_upload(){
  local emuName=$1
  local timestamp=$(date +%s)
  
  if [ $cloud_sync_status = "true" ]; then
    cloud_sync_lock
    if [ $emuName = 'all' ]; then           
        ("$toolsPath/rclone/rclone" copy --fast-list --checkers=50 -P -L "$savesPath" --exclude=/.fail_upload --exclude=/.fail_download --exclude=/.pending_upload "$cloud_sync_provider":Emudeck/saves/ && (          
          local baseFolder="$savesPath/"
           for folder in $baseFolder*/
            do
              if [ -d "$folder" ]; then
               emuName=$(basename "$folder")
               echo $timestamp > "$savesPath"/.last_upload && rm -rf $savesPath/.fail_upload
              fi
          done          
        ))
    else
        ("$toolsPath/rclone/rclone" copy --fast-list --checkers=50 -P -L "$savesPath/$emuName/" --exclude=/.fail_upload --exclude=/.fail_download --exclude=/.pending_upload "$cloud_sync_provider":Emudeck/saves/$emuName/ && echo $timestamp > "$savesPath"/$emuName/.last_upload && rm -rf $savesPath/$emuName/.fail_upload)
    fi
  fi
  
  cloud_sync_unlock
}

cloud_sync_download(){
  local emuName=$1
  local timestamp=$(date +%s)
  if [ $cloud_sync_status = "true" ]; then
  
    #We wait for any upload in progress in the background
    cloud_sync_check_lock
    if [ $emuName = 'all' ]; then
        #We check the hashes
        local filePath="$savesPath/.hash"
        local hash=$(cat "$savesPath/.hash")
        
        $cloud_sync_bin  --progress copyto --fast-list --checkers=50 --transfers=50 --low-level-retries 1 --retries 1 "$cloud_sync_provider":Emudeck\saves\.hash "$filePath" 
                        
        hashCloud=$(cat "$savesPath\.hash")
                
        if [ -f "$savesPath/.hash" ];then           
          if [ $hash = $hashCloud ]; then
            echo "up to date"
            else
             ("$toolsPath/rclone/rclone" copy --fast-list --checkers=50 -P -L "$cloud_sync_provider":Emudeck/saves/ --exclude=/.fail_upload --exclude=/.fail_download --exclude=/.pending_upload "$savesPath" && (          
               local baseFolder="$savesPath/"
                for folder in $baseFolder*/
                 do
                   if [ -d "$folder" ]; then
                    emuName=$(basename "$folder")
                    echo $timestamp > "$savesPath"/$emuName/.last_download && rm -rf $savesPath/$emuName/.fail_download && rm -rf $savesPath/$emuName/.pending_upload
                   fi
               done          
             )) | zenity --progress --title="Downloading saves - All systems" --text="Syncing saves..." --auto-close --width 300 --height 100 --pulsate  
          fi
        else
          ("$toolsPath/rclone/rclone" copy --fast-list --checkers=50 -P -L "$cloud_sync_provider":Emudeck/saves/ --exclude=/.fail_upload --exclude=/.fail_download --exclude=/.pending_upload "$savesPath" && (          
             local baseFolder="$savesPath/"
              for folder in $baseFolder*/
               do
                 if [ -d "$folder" ]; then
                  emuName=$(basename "$folder")
                  echo $timestamp > "$savesPath"/$emuName/.last_download && rm -rf $savesPath/$emuName/.fail_download
                 fi
             done          
           )) | zenity --progress --title="Downloading saves - All systems" --text="Syncing saves..." --auto-close --width 300 --height 100 --pulsate  
        fi
      #Single Emu
      else          
        #We check the hashes
        local filePath="$savesPath/.hash"
        local hash=$(cat "$savesPath/.hash")
        
        $cloud_sync_bin  --progress copyto --fast-list --checkers=50 --transfers=50 --low-level-retries 1 --retries 1 "$cloud_sync_provider":Emudeck\saves\.hash "$filePath" 
                        
        hashCloud=$(cat "$savesPath\.hash")
                
        if [ -f "$savesPath/.hash" ];then           
          if [ $hash = $hashCloud ]; then
            echo "nothig to download"
          else
            ("$toolsPath/rclone/rclone" copy --fast-list --checkers=50 -P -L "$cloud_sync_provider":Emudeck/saves/$emuName/ --exclude=/.fail_upload --exclude=/.fail_download --exclude=/.pending_upload "$savesPath"/$emuName/ && echo $timestamp > "$savesPath"/$emuName/.last_download && rm -rf $savesPath/$emuName/.fail_download) | zenity --progress --title="Downloading saves $emuName" --text="Syncing saves..." --auto-close --width 300 --height 100 --pulsate  
          fi          
        else
          ("$toolsPath/rclone/rclone" copy --fast-list --checkers=50 -P -L "$cloud_sync_provider":Emudeck/saves/$emuName/ --exclude=/.fail_upload --exclude=/.fail_download --exclude=/.pending_upload "$savesPath"/$emuName/ && echo $timestamp > "$savesPath"/$emuName/.last_download && rm -rf $savesPath/$emuName/.fail_download) | zenity --progress --title="Downloading saves $emuName" --text="Syncing saves..." --auto-close --width 300 --height 100 --pulsate  
        fi
    fi
  fi

}

cloud_sync_uploadEmu(){
  local emuName=$1
  local mode=$2
  local time_stamp
  if [ -f "$toolsPath/rclone/rclone" ]; then    
  
    #We check for internet connection
    if [[ $(check_internet_connection) == true ]]; then
      
      #Do we have a failed upload?
      if [ -f $savesPath/$emuName/.fail_upload ]; then
          
       time_stamp=$(cat $savesPath/$emuName/.fail_upload)       
       date=$(date -d @"$timestamp" +"%Y-%m-%d")
       hour=$(date -d @"$timestamp" +"%H:%M:%S")
       while true; do
         ans=$(zenity --question \
            --title="CloudSync conflict $emuName" \
            --text="We've detected a previously failed upload, do you want us to upload your saves and overwrite your saves in the cloud? Your latest upload was on $date $hour" \
            --extra-button "No, download from the cloud and overwrite my local saves" \
            --cancel-label="Skip for now" \
            --ok-label="Yes, upload them" \
            --width=400)
         rc=$?
         response="${rc}-${ans}"
          break
        done
        
        if [[ $response =~ "download" ]]; then
          #Download - Extra
          rm -rf $savesPath/$emuName/.pending_upload
          cloud_sync_download $emuName
          
        elif [[ $response =~ "0-" ]]; then
          #Upload - OK
          rm -rf $savesPath/$emuName/.pending_upload
          cloud_sync_upload $emuName
          
        else
          #Skip - Cancel
          return
        fi
      
      else        
      #Upload
        rm -rf $savesPath/$emuName/.pending_upload       
       #Download 
       if [ -z $mode ];then
         echo "uploading one"
         cloud_sync_upload $emuName 
       fi
      fi  
    
    else
    # No internet? We mark it as failed
      echo $timestamp > $savesPath/$emuName/.fail_upload
    fi   
    
  fi
}

cloud_sync_downloadEmu(){
  local emuName=$1
  local mode=$2
  if [ -f "$toolsPath/rclone/rclone" ]; then    
    local timestamp=$(date +%s)
    
    #We check for internet connection
    if [[ $(check_internet_connection) == true ]]; then
      
      #Do we have a pending upload?
      if [ -f $savesPath/$emuName/.pending_upload ]; then
        time_stamp=$(cat $savesPath/$emuName/.pending_upload)
        date=$(date -d @"$timestamp" +"%Y-%m-%d")
        hour=$(date -d @"$timestamp" +"%H:%M:%S")        
        while true; do
          ans=$(zenity --question \
             --title="CloudSync conflict $emuName" \
             --text="We've detected a pending upload, make sure you don't close $emuName using the Steam Button. Do you want us to upload your saves to the cloud and overwrite them? This upload should have happened on $date $hour" \
             --extra-button "No, download from the cloud and overwrite my local saves" \
             --cancel-label="Skip for now" \
             --ok-label="Yes, upload them" \
             --width=400)
          rc=$?
          response="${rc}-${ans}"
            break
        done
        
        if [[ $response =~ "download" ]]; then
          #Download - OK
          cloud_sync_download $emuName
          echo $timestamp > "$savesPath"/$emuName/.pending_upload
        elif [[ $response =~ "0-" ]]; then
          
          #Upload - Extra button
          rm -rf $savesPath/$emuName/.pending_upload
          cloud_sync_upload $emuName
        else
          #Skip - Cancel
          return
        fi
      fi    
      
      echo $timestamp > "$savesPath/$emuName/.pending_upload"
      
      #Do we have a failed download?
      if [ -f $savesPath/$emuName/.fail_download ]; then
      time_stamp=$(cat $savesPath/$emuName/.fail_download)
      date=$(date -d @$time_stamp +'%x')
      while true; do
        ans=$(zenity --question \
           --title="CloudSync conflict $emuName" \
           --text="We've detected a previously failed download, do you want us to download your saves from the cloud and overwrite your local saves? Your latest download was on $date" \
           --extra-button "No, upload to the cloud and overwrite my cloud saves" \
           --cancel-label="Skip for now" \
           --ok-label="Yes, download them" \
           --width=400)
        rc=$?
        response="${rc}-${ans}"
          break
        done
      
        if [[ $response =~ "upload" ]]; then
          #Upload - Extra button
          rm -rf $savesPath/$emuName/.pending_upload
          cloud_sync_upload $emuName
        elif [[ $response =~ "0-" ]]; then
          #Download - OK
          cloud_sync_download $emuName
        else
          #Skip - Cancel
          return
        fi

        
      else        
        #Download 
        if [ -z $mode ];then
          echo "downloading one"
          cloud_sync_download $emuName        
        fi
      fi
    else
    # No internet? We mark it as failed
      echo $timestamp > "$savesPath"/$emuName/.fail_download
    fi  
  fi
}

cloud_sync_downloadEmuAll(){
 local baseFolder="$savesPath/"
 for folder in $baseFolder*/
  do
    if [ -d "$folder" ]; then
      emuName=$(basename "$folder")
      cloud_sync_downloadEmu $emuName 'check-conflicts'
    fi
  done
  cloud_sync_download 'all'
}


cloud_sync_uploadEmuAll(){
 local baseFolder="$savesPath/"
 for folder in $baseFolder*/
  do
    if [ -d "$folder" ]; then
      emuName=$(basename "$folder")
      cloud_sync_uploadEmu $emuName 'check-conflicts'
    fi
  done
  cloud_sync_upload 'all'
}



function cloud_sync_save_hash(){
  local $dir
  hash=$(find "$dir" -maxdepth 1 -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')
  echo "$hash"  
}



cloud_sync_createService(){
  echo "Creating CloudSync service"
  local service_name="EmuDeckCloudSync"
  local script_path="$HOME/.config/EmuDeck/backend/tools/cloudSync/cloud_sync_watcher.sh"  
  local user_service_dir="$HOME/.config/systemd/user/"
  
  touch "$user_service_dir/$service_name.service"
  cat <<EOF > "$user_service_dir/$service_name.service"
[Unit]
Description=$description

[Service]
ExecStart=/bin/bash $script_path
Restart=always

[Install]
WantedBy=default.target
EOF

  echo "$service_name created"
}

cloud_sync_startService(){
  systemctl --user stop "EmuDeckCloudSync.service"
  systemctl --user start "EmuDeckCloudSync.service"
}

cloud_sync_stopService(){
  systemctl --user stop "EmuDeckCloudSync.service"
}


cloud_sync_lock(){
 touch "$HOME/emudeck/cloud.lock"
}

cloud_sync_unlock(){
  rm -rf "$HOME/emudeck/cloud.lock"
}

cloud_sync_check_lock(){
  lockedFile="$HOME\emudeck\cloud.lock"
  
  if [ -f $lockedFile ]; then
   text="$(printf "<b>CloudSync in progress!</b>\nWe're syncing your saved games, please wait...")"     
     zenity --info --width=300 --text="${text}" 2>/dev/null 
     local zenity_pid=$!
  fi
  
  while [ -f $lockedFile ]
  do
    sleep 1
  done
  
  if [ -n "$zenity_pid" ]; then
    kill "$zenity_pid"
  fi
  
}