import {
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Divider,
  TextField,
  Typography,
} from "@mui/material";
import GoogleIcon from "@mui/icons-material/Google";
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { getToken } from "../services/localStorageService";
import keycloak from "../keycloak";

export default function Login() {
  const navigate = useNavigate();

  const handleNavigateRegistration = () => {
    navigate("/registration");
  };

  const handleClickGoogle = () => {
    // Trigger login with Google
    keycloak
      .login({
        idpHint: "google", // Use Google as the identity provider
      })
      .then(() => {
        if (keycloak.authenticated) {
          console.log("Logged in with Google");
  
          // Fetch the user profile after successful login
          keycloak.loadUserProfile().then((profile) => {
            console.log("User profile:", profile);
  
            // Access token
            const token = keycloak.token;
  
            // Use the token to send data to your backend
            fetch("http://localhost:8080/profile/my-profile", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${token}`, // Include the access token in the Authorization header
              },
              body: JSON.stringify({
                // Your data here
                username: profile.username,
                email: profile.email,
                firstName: profile.firstName,
                lastName: profile.lastName,
              }),
            })
            .then(response => response.json())
            .then(data => {
              console.log("Data sent to backend:", data);
              navigate("/dashboard"); // Redirect after successful data handling
            })
            .catch(error => {
              console.error("Error sending data to backend:", error);
            });
          });
        } else {
          console.log("User not authenticated");
        }
      })
      .catch((error) => {
        console.error("Keycloak login with Google failed", error);
      });
  };
  

  useEffect(() => {
    const accessToken = getToken();

    if (accessToken) {
      navigate("/");
    }

    if (keycloak.authenticated) {
      keycloak.loadUserProfile().then((profile) => {
        console.log("User profile:", profile);
  
        // Access token
        const token = keycloak.token;
        console.log(token);
        
      });
    }
    
  }, [navigate]);

  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  const handleSubmit = (event) => {
    event.preventDefault();
    // Handle form submission
    console.log("Username:", username);
    console.log("Password:", password);
  };

  return (
    <>
      <Box
        display="flex"
        flexDirection="column"
        alignItems="center"
        justifyContent="center"
        height="100vh"
        bgcolor={"#f0f2f5"}
      >
        <Card
          sx={{
            minWidth: 250,
            maxWidth: 400,
            boxShadow: 4,
            borderRadius: 4,
            padding: 4,
          }}
        >
          <CardContent>
            <Typography variant="h5" component="h1" gutterBottom>
              Welcome to My App
            </Typography>
            <Box component="form" onSubmit={handleSubmit} sx={{ mt: 2 }}>
              <TextField
                label="Username"
                variant="outlined"
                fullWidth
                margin="normal"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
              />
              <TextField
                label="Password"
                type="password"
                variant="outlined"
                fullWidth
                margin="normal"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </Box>
          </CardContent>
          <CardActions>
            <Box display="flex" flexDirection="column" width="100%" gap="25px">
              <Button
                type="submit"
                variant="contained"
                color="primary"
                size="large"
                fullWidth
              >
                Login
              </Button>
              <Button
                type="button"
                variant="contained"
                color="secondary"
                size="large"
                onClick={handleClickGoogle}
                fullWidth
                sx={{ gap: "10px" }}
              >
                <GoogleIcon />
                Continue with Google
              </Button>
              <Divider></Divider>
              <Button
                type="submit"
                variant="contained"
                color="success"
                size="large"
                onClick={handleNavigateRegistration}
              >
                Create an account
              </Button>
            </Box>
          </CardActions>
        </Card>
      </Box>
    </>
  );
}
