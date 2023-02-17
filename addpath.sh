#!/bin/bash
#A script to add this direcotry to ~/.bash_aliases or ~/.bash_profile

echo "Which OS are you using? Select number."
select os in "Linux" "MacOS" "quit"
do
  if [ "$REPLY" = "q" ] ; then
    echo "quit."
    exit 0
  fi
  if [ -z "$os" ] ; then
    continue
  elif [ $os == "Linux" ] ; then
    grep '# PATH for batch_heudiconv' ~/.bash_aliases > /dev/null
    if [ $? -eq 1 ]; then
      echo '' >> ~/.bash_aliases
      echo '#PATH for batch_heudiconv' >> ~/.bash_aliases
      echo "export PATH=\$PATH:$PWD" >> ~/.bash_aliases
      echo "PATH for batch_heudiconv was added to ~/.bash_aliases"
      echo "Please close the terminal, re-open and run checkpath.sh."

      break
    fi

  elif [ $os == "MacOS" ] ; then
    grep '# PATH for batch_heudiconv' ~/.bash_profile > /dev/null
    if [ $? -eq 1 ]; then
      echo '' >> ~/.bash_profile
      echo '#PATH for batch_heudiconv' >> ~/.bash_profile
      echo "export PATH=\$PATH:$PWD" >> ~/.bash_profile
      echo "PATH for batch_heudiconv was added to ~/.bash_profile"
      echo "Please close the terminal, re-open and run checkpath.sh."

      break
    fi
  elif [ $os == "quit" ] ; then
     echo "quit."
     exit 0
  fi
done
