<?php
  // Make sure all the error message are the same to limit the amount of information one can gathers from calling the API
  $errorMessage = "An error occur, please retry...";

  if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['state']) && isset($_POST['accessToken'])) {

    // Get the info from the config file
    $configFile = 'store_access_token_config.json'; 
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
    
    $state = $_POST['state'];
    $stateInt = intval($state);
    
    // Validate the state
    $hasValidLen = strlen($state) == 16;
    $isNumeric = preg_match('/^\d+$/', $state);
    $isChecksumValid = array_sum(str_split($state)) % 7 === 1;
    $hasMarkers = $state[5] === '4' && $state[11] === '2';
    if (!$hasValidLen || !$isNumeric || !$isChecksumValid || !$hasMarkers) {
      die($errorMessage);
    }

    // Create connection
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    // Check connection
    if ($conn->connect_error) {
     die($errorMessage);
    }

    $accessToken = $_POST['accessToken'];
    $sql = "INSERT INTO ".$dbtable." (state, token) VALUES ('".$state."', '".$accessToken."')";
    try{
      $conn->query($sql);
      echo "You successfully connected to Twitch.tv.\nYou can now close this page.";
    } catch (Exception $e) {
      echo $errorMessage;
    }

    $conn->close();

  } else {
    die($errorMessage);
  }
?>

