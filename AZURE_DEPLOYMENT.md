# Azure App Service Deployment Guide

## Prerequisites

1. **Azure Account**: Ensure you have an active Azure subscription
2. **Azure CLI** (optional): For command-line deployment
3. **GitHub Account**: For CI/CD pipeline

## Step 1: Create Azure App Service

### Option A: Using Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Click "Create a resource" → "Web App"
3. Fill in the details:
   - **Resource Group**: Create new or use existing
   - **Name**: Choose a unique name (e.g., `bidashboard-app`)
   - **Publish**: Code
   - **Runtime Stack**: Python 3.11
   - **Operating System**: Linux
   - **Region**: Choose closest to your users
   - **Pricing Tier**: F1 (Free) for testing, B1 for production

### Option B: Using Azure CLI

```bash
# Login to Azure
az login

# Create resource group
az group create --name bidashboard-rg --location "East US"

# Create App Service plan
az appservice plan create --name bidashboard-plan --resource-group bidashboard-rg --sku B1 --is-linux

# Create web app
az webapp create --resource-group bidashboard-rg --plan bidashboard-plan --name your-unique-app-name --runtime "PYTHON|3.11"
```

## Step 2: Configure App Service Settings

### Application Settings (Environment Variables)

In Azure Portal → Your App Service → Configuration → Application settings:

```
SECRET_KEY=your-very-long-secret-key-here-at-least-32-characters
FRONTEND_URL=https://your-app-name.azurewebsites.net
PYTHONPATH=/home/site/wwwroot
SCM_DO_BUILD_DURING_DEPLOYMENT=true
```

### General Settings

- **Stack**: Python
- **Major Version**: 3.11
- **Startup Command**: `python startup.py`

## Step 3: Set up GitHub Actions Deployment

### Get Publish Profile

1. In Azure Portal → Your App Service → Overview
2. Click "Get publish profile" and download the `.publishsettings` file
3. Copy the entire content of this file

### Configure GitHub Secrets

1. Go to your GitHub repository → Settings → Secrets and variables → Actions
2. Create a new secret:
   - **Name**: `AZUREAPPSERVICE_PUBLISHPROFILE`
   - **Value**: Paste the entire publish profile content

### Update Deployment Workflow

Edit `.github/workflows/azure-deploy.yml` and replace:
```yaml
AZURE_WEBAPP_NAME: your-app-name  # Replace with your actual app name
```

## Step 4: Deploy

### Option A: Automatic Deployment (Recommended)

1. Push your changes to the `master` branch:
```bash
git add .
git commit -m "Configure Azure deployment"
git push origin master
```

2. GitHub Actions will automatically build and deploy your application

### Option B: Manual Deployment

1. Zip your project (excluding `node_modules`, `.git`, etc.)
2. In Azure Portal → Your App Service → Deployment Center
3. Choose "External Git" or upload ZIP file directly

## Step 5: Verify Deployment

1. Wait for deployment to complete (check GitHub Actions or Azure Portal)
2. Visit `https://your-app-name.azurewebsites.net`
3. Your BIDashboard should be running!

## Troubleshooting

### Common Issues

1. **Build failures**: Check GitHub Actions logs
2. **Python errors**: Verify requirements.txt and Python version
3. **CORS issues**: Ensure FRONTEND_URL is set correctly
4. **File permissions**: Azure handles this automatically for Linux apps

### Logs

View logs in Azure Portal → Your App Service → Log stream

### Local Testing

Test the production build locally:
```bash
cd frontend
npm run build
cd ../backend
python main.py
```

## Production Considerations

1. **Custom Domain**: Configure in Azure Portal → Custom domains
2. **SSL Certificate**: Free SSL is provided by Azure
3. **Scale**: Upgrade to higher tier plans for better performance
4. **Database**: Consider Azure SQL or CosmosDB for production
5. **File Storage**: Use Azure Blob Storage for uploaded files
6. **Security**: Review and update SECRET_KEY regularly

## Cost Optimization

- **Free Tier**: F1 plan (limited resources, sleeps after inactivity)
- **Basic Tier**: B1 plan ($13-15/month, no auto-sleep)
- **Monitor Usage**: Set up billing alerts in Azure

Your BIDashboard is now ready for production on Azure App Service!