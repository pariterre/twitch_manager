<?php 
  // Make sure all the error message are the same to limit the amount of information one can gathers from calling the API
  $errorMessage = "An error occur, please retry...";

  // Get the info from the config file
  $configFile = 'get_access_token_config.json'; 
  $configData = file_get_contents($configFile);
  $config = json_decode($configData, true);
  if ($config === null) {
    die($errorMessage);
  }

  // Parse the config file
  $servername = $config['servername'];
  $username = $config['username'];
  $password = $config['password'];
  $dbname = $config['dbname'];
  $dbtable = $config['dbtable'];


  // Create connection
  $conn = new mysqli($servername, $username, $password, $dbname);
  // Check connection
  if ($conn->connect_error) {
    die($errorMessage);
  }

  // Retrieve state sent from the main app
  $state = $_GET['state']; // Assuming the state is sent as a query parameter
  
  $sql = "SELECT token FROM " . $dbtable . " WHERE state=" . $state . " LIMIT 1";
  $result = $conn->query($sql);

  if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode($row);
  
    // sql to delete a record
    $sql = "DELETE FROM " . $dbtable . " WHERE state=" . $state;
    try{
      $conn->query($sql);
    } catch (Exception $e) {
      // pass
    }

  } else {
    $row = array("token" => "error");
    echo json_encode($row);
  }

  $conn->close();

?> 
