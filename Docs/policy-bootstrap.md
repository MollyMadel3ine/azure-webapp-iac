Azure Policy — one-time elevated bootstrap (run as YOU, not the SP)

Run once with your own `az login` credentials, like the state storage
bootstrap. Both use built-in policy definitions, scoped to the project
resource group.

```powershell
$rg = az group show --name rg-webapp-demo --query id -o tsv

# Policy 1: require a 'project' tag on resources in the RG
az policy assignment create `
  --name "require-project-tag" `
  --display-name "Require project tag on resources" `
  --policy "871b6d14-10aa-478d-b590-94f262ecfa99" `
  --params '{ \"tagName\": { \"value\": \"project\" } }' `
  --scope $rg

# Policy 2: deny public IPs on network interfaces in the RG
az policy assignment create `
  --name "deny-nic-public-ip" `
  --display-name "Network interfaces should not have public IPs" `
  --policy "83a86a26-fd1f-447c-b59d-e51f44264114" `
  --scope $rg
```

Notes:
- The GUIDs are Azure built-in policy definition IDs (require-tag and
  deny-NIC-public-IP respectively).
- Scoping to the RG (not the subscription) keeps the blast radius to
  this project.
- Caveat to document: because Terraform destroys and recreates the RG,
  these assignments die with it — re-run this bootstrap after a full
  destroy/rebuild. That trade-off (vs. granting the pipeline policy
  rights) is deliberate; say so in the README.

