#!/bin/bash

sitesAvailable=()
sitesEnabled=()
reallyAvailable=()
title="--------------------------------------------\nWelcome to VHM, your Virtual Hosts Manager !\n--------------------------------------------\n"


# Get list of sites available
_getSitesAvailable ()
{
  i=0
  for file in `ls /etc/apache2/sites-available/`; do
    sitesAvailable[ $i ]="$file"
    (( i++ ))
  done
}

# Get list of sites enabled
_getSitesEnabled ()
{
  i=0
  for file in `ls /etc/apache2/sites-enabled/`; do
    sitesEnabled[ $i ]="$file"
    (( i++ ))
  done
}

# Get list of sites available & not enabled
_getReallyAvailable ()
{
  i=0
  j=0
  for fileAvailable in ${sitesAvailable[*]}; do
    enabled=false
    
    for fileEnabled in ${sitesEnabled[*]}; do
      if [ $fileAvailable = $fileEnabled ]; then
        enabled=true
      fi
    done

    if [ $enabled = false ]; then
      reallyAvailable[ $j ]="$i;$fileAvailable"
      (( j++ ))
    fi
    
    (( i++ ))
  done
}

# Generate a virtual host code
_getVirtualCode ()
{
  cat << EOF > /etc/apache2/sites-available/$1.conf.temp
  <VirtualHost $1>
    ServerName $1
    ServerAdmin $2
    DocumentRoot $3

    ErrorLog \${APACHE_LOG_DIR}/$1-error.log
    CustomLog \${APACHE_LOG_DIR}/$1-access.log combined
  </VirtualHost>
EOF
}

# Create a virtual host
create-vhost ()
{
  echo -e $title
  echo "You will create a new virtual host."
  echo ""
    
  while [ -z $url ]; do
    read -p "Url of the virtual host ? (ex. \"hello.dev\") " url
  done

  read -p "Email of the Admin server ? (default. \"webmaster@localhost\") " email
  if [ -z $email ]; then
    email="webmaster@localhost"
  fi

  while [ -z $root ]; do
    read -p "Root of the files ? (ex. \"/home/me/www/name_of_the_project/\") " root
  done

  echo ""
  echo "* Creating the final code..."
  _getVirtualCode $url $email $root # Generate a temporary file
  cat /etc/apache2/sites-available/$url.conf.temp # Print file
  
  echo ""
  read -p "Are you agree ? (Y/n) " response
  if [ $response = "Y" ]; then
    echo "* Preparing the file..."
    sudo mv /etc/apache2/sites-available/$url.conf.temp /etc/apache2/sites-available/$url.conf

    echo ""
    read -p "Do you want to enable it ? (Y/n) " response
    if [ $response = "Y" ]; then
      enable-vhost $url # Launch the enabling process
    else
      echo "Okay ! Bye !"
    fi
  else
    echo "Creation aborted ! Bye !"
  fi
}

# Edit a virtual host
edit-vhost ()
{
  echo -e $title
  echo "You will edit a virtual host."

  i=0
  for fileAvailable in ${sitesAvailable[*]}; do
    printf "$i) %s\n" "$fileAvailable"
    (( i++ ))
  done

  echo ""
  read -p "Which project do you want to edit ? (Select a number) " whichEdit
  if [ "$whichEdit" -ge 0 ] && [ "$whichEdit" -le $i ]; then
    echo "* Launch editor..."
    echo "* Editing the virtual host..."
    sudo nano /etc/apache2/sites-available/${sitesAvailable[$whichEdit]}

    alreadyEnabled=false
    for fileEnabled in ${sitesEnabled[*]}; do
      if [ $fileEnabled = ${sitesAvailable[$whichEdit]} ]; then
        alreadyEnabled=true
      fi
    done

    if [ $alreadyEnabled = true ]; then
      echo "* Re-enable the virtual host..."; sudo a2ensite ${sitesAvailable[$whichEdit]} &> /dev/null
      echo "* Restarting Apache..."; sudo service apache2 restart &> /dev/null
    fi

    echo ""
    echo "Site \"${sitesAvailable[$whichEdit]::-5}\" edited successfully !"
  else
    echo "Bad choice ! Bye !"
  fi
}

# Disable & delete a virtual host
remove-vhost ()
{
  echo -e $title
  echo "You will delete a virtual host."

  i=0
  for fileEnabled in ${sitesEnabled[*]}; do
    printf "$i) %s\n" "$fileEnabled"
    (( i++ ))
  done

  echo ""
  read -p "Which project do you want to remove ? (Select a number) " whichEnabled
  if [ "$whichEnabled" -ge 0 ] && [ "$whichEnabled" -le $i ]; then
    read -p "Are you sure to want to remove \"${sitesEnabled[$whichEnabled]}\" ? (Y/n) " response
    
    if [ $response = "Y" ]; then
      disable-vhost ${sitesEnabled[$whichEnabled]} # Launch the disabling process
      echo "* Delete site file..."
      rm /etc/apache2/sites-available/${sitesEnabled[$whichEnabled]}
      echo ""
      echo "Site \"${sitesEnabled[$whichEnabled]::-5}\" removed successfully !"
    else
      echo "Removing aborted, bye !"
    fi
  else
    echo "Bad choice ! Retry !"
  fi
}

# Enable a virtual host
enable-vhost ()
{
  # If there's a filename parameter ( for example from "create-vhost" )
  if [ ! -z $1 ]; then
    siteToEnable=$1
  else
    echo -e $title
    echo "List of available sites :"

    _getReallyAvailable
    i=0
    
    for fileAvailable in ${reallyAvailable[*]}; do
      entry=(${fileAvailable//;/ })
      printf "$entry) %s\n" "${entry[1]}"
      (( i++ ))
    done

    echo ""
    read -p "Which project would you enable ? (Select a number) " whichAvailable
    if [ "$whichAvailable" -ge 0 ] && [ "$whichAvailable" -le $entry ]; then
      read -p "Are you sure to want to enable \"${sitesAvailable[$whichAvailable]}\" ? (Y/n) " response

      if [ $response = "Y" ]; then
        siteToEnable=${sitesAvailable[$whichAvailable]::-5}
      else
        echo "Enabling aborted, bye !"; break=true
      fi
    else
      echo "Bad choice ! Retry !"; break=true
    fi
  fi

  if [ -z $break ]; then
    echo ""
    echo "* Enabling site..."; sudo a2ensite $siteToEnable.conf &> /dev/null
    echo "* Add to hosts list..."; echo "127.0.0.1       $siteToEnable" >> /etc/hosts
    echo "* Restarting Apache..."; sudo service apache2 restart &> /dev/null
    echo ""
    echo "Site \"$siteToEnable\" enabled successfully !"
  fi
}

# Disable a virtual host
disable-vhost ()
{
  # If there's a filename parameter ( for example from "remove-vhost" )
  if [ ! -z $1 ]; then
    siteToDisable=$1
  else
    echo -e $title
    echo "List of enabled sites :"

    i=0
    for fileEnabled in ${sitesEnabled[*]}; do
      printf "$i) %s\n" "$fileEnabled"
      (( i++ ))
    done

    echo ""
    read -p "Which project do you want to disable ? (Select a number) " whichEnabled
    if [ "$whichEnabled" -ge 0 ] && [ "$whichEnabled" -le $i ]; then
      read -p "Are you sure to want to disable \"${sitesEnabled[$whichEnabled]}\" ? (Y/n) " response

      if [ $response = "Y" ]; then
        siteToDisable=${sitesEnabled[$whichEnabled]}
      else
        echo "Disabling aborted, bye !"; break=true
      fi
    else
      echo "Bad choice ! Retry !"; break=true
    fi
  fi

  if [ -z $break ]; then
    echo ""
    echo "* Disabling site..."; sudo a2dissite $siteToDisable &> /dev/null
    echo "* Remove to hosts list..."; sed -i "/127.0.0.1       ${siteToDisable::-5}/d" /etc/hosts &> /dev/null
    if [ -z $1 ]; then
      echo "* Restarting Apache..."; sudo service apache2 restart &> /dev/null
      echo ""
      echo "Site \"${siteToDisable::-5}\" disabled successfully !"
    fi
  fi
}

# Help
help-vhost ()
{
  echo -e $title
  echo "Commands :"
  echo "- 'list': List all Virtual Hosts."
  echo "- 'create': Create a Virtual Host."
  echo "- 'edit': Edit a Virtual Host."
  echo "- 'remove': Disable & delete a Virtual Host."
  echo "- 'enable': Enable a Virtual Host."
  echo "- 'disable': Disable a Virtual Host."
  echo "- 'install': Setup Virtual Hosts Manager."
  echo "- 'uninstall': Uninstall Virtual Hosts Manager."
}

# Setup VHM
setup-vhost ()
{
  echo -e $title
  echo "You will install VHM on your computer. Commands lines will be simpler."
  echo ""
  echo "For example, you can type \"sudo vhost create\" instead of \"sudo /path_to_the_script/vhost.sh create\"."
  read -p 'Do you want to install VHM ? (Y/n) ' response

  if [ $response = "Y" ]; then
    echo ""
    echo "* Copy script to /usr/local/bin/..."
    sudo cp ./vhost.sh /usr/local/bin
    echo "* Rename script to \"vhost\"..."
    sudo mv /usr/local/bin/vhost.sh /usr/local/bin/vhost
    echo "* Change of file execution permission..."
    sudo chmod +x /usr/local/bin/vhost
    echo ""
    echo "Setup complete ! You can try the script by typing 'sudo vhost'"
  else
    echo "Setup aborted, bye !"
  fi
}

# Uninstall VHM from the computer
uninstall-vhost ()
{
  echo -e $title
  read -p 'Do you want to remove VHM ? (Y/n) ' response

  if [ $response = "Y" ]; then
    echo ""
    echo "* Remove script from /usr/local/bin/..."
    sudo rm /usr/local/bin/vhost
    echo ""
    echo "Remove complete ! bye !"
  else
    echo "Remove aborted, bye !"
  fi
}

# List all the virtual hosts
list-vhost ()
{
  echo -e $title
  echo "List of available sites :"
  printf -- "- %s\n" "${sitesAvailable[@]}"

  echo ""
  echo "List of enabled sites :"
  printf -- "- %s\n" "${sitesEnabled[@]}"
}

_getSitesAvailable
_getSitesEnabled


# Create a virtual host
case $1 in
  "list") list-vhost;;
  "create") create-vhost;;
  "edit") edit-vhost;;
  "remove") remove-vhost;;
  "enable") enable-vhost;;
  "disable") disable-vhost;;
  "install") setup-vhost;;
  "uninstall") uninstall-vhost;;
  *) help-vhost;;
esac