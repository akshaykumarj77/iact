#!/bin/bash
 
LOGFILE="logs/environment_script.log"
 
# Function to log messages with date and time
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOGFILE
}
 
# Function to display the environment options
show_menu() {
  log_message "Displaying environment selection menu"
  echo "Select environment:"
  echo "1) Development (dev)"
  echo "2) Pre-production (preprod)"
  echo "3) Production (prod)"
}
 
# Function to execute commands based on the environment
run_command() {
  case $1 in
    dev)
      log_message "Running command in Development environment"
      # Place the command(s) to run in the dev environment here
      ;;
    preprod)
      echo "Running command in Pre-production environment"
      # Place the command(s) to run in the preprod environment here
      ;;
    prod)
      echo "Running command in Production environment"
      # Place the command(s) to run in the prod environment here
      ;;
    *)
      log_message "Invalid environment"
      exit 1
      ;;
  esac
}
 
# Display the menu and get user input
show_menu
read -p "Enter your choice (1-3): " choice
log_message "User selected option $choice"
 
# Map user input to environment
case $choice in
  1)
    ENV="dev"
    ;;
  2)
    ENV="preprod"
    ;;
  3)
    ENV="prod"
    ;;
  *)
    log_message "Invalid choice"
    echo "Invalid choice"
    exit 1
    ;;
esac
 
# Run the command for the selected environment
# run_command $ENV
helmfile --environment $ENV apply --interactive
log_message "Command execution completed for $ENV environment"
