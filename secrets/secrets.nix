let
  adamphoenix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbkiG2A7A1MbqAVzOBB/rJxXYAl5gSymsjhIKHaETdy";
  adamalchemist = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILB1AzLhbytJCN8V6o/BxnJ7hka4J8GoZWRR9lwvELKr";
  users = [adamphoenix adamalchemist];

  phoenix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAhmY3KmEMBxCGFeYgG4YWWS0crMnQSMnI2f9Jvu4Y/ root@nixos";
  systems = [phoenix];

  all = systems ++ users;
in {
  "home-assistant.age".publicKeys = systems ++ users;
  "jellystat.age".publicKeys = systems ++ users;
}
