# Environment Variables Setup Guide

## Overview
This project uses environment variables to securely store API keys. This prevents accidentally committing sensitive keys to version control.

## Setup Steps

### 1. Install Dependencies
Make sure you've run:
```bash
flutter pub get
```

### 2. Create .env File
Copy the example file and create your `.env` file:
```bash
cp env.example .env
```

### 3. Add Your API Keys
Open the `.env` file and replace the placeholder values with your actual API keys:

```env
# OpenAI API Key (for heart rate analysis)
OPENAI_API_KEY=sk-your-actual-openai-key-here

# ElevenLabs API Key (for text-to-speech)
ELEVENLABS_API_KEY=sk-your-actual-elevenlabs-key-here
```

### 4. Get Your API Keys

#### OpenAI API Key
1. Go to https://platform.openai.com/api-keys
2. Sign in or create an account
3. Click "Create new secret key"
4. Copy the key and paste it in `.env`

#### ElevenLabs API Key
1. Go to https://elevenlabs.io
2. Sign in or create an account
3. Navigate to your profile/settings
4. Copy your API key and paste it in `.env`

## Security Best Practices

✅ **DO:**
- Keep `.env` file local (never commit to git)
- Use different keys for development and production
- Rotate keys if they're accidentally exposed
- Use `.env.example` as a template (without real keys)

❌ **DON'T:**
- Commit `.env` to version control
- Share `.env` files via email or chat
- Hardcode API keys in source code
- Use production keys in development

## File Structure

```
renovatio/
├── .env                 # Your actual API keys (NOT in git)
├── env.example          # Template file (safe to commit)
├── .gitignore          # Ensures .env is ignored
└── lib/
    └── services/
        └── config_service.dart  # Reads from .env
```

## Verification

After setting up your `.env` file, run the app. You should see:
```
✅ Environment variables loaded successfully
```

If you see warnings, check:
1. `.env` file exists in the project root
2. File format is correct (no spaces around `=`)
3. API keys are valid

## Troubleshooting

### Error: "Could not load .env file"
- Make sure `.env` file exists in the project root (same level as `pubspec.yaml`)
- Check file permissions
- Verify the file is not empty

### Error: "API key not configured"
- Check that keys are set in `.env` file
- Verify key names match exactly: `OPENAI_API_KEY` and `ELEVENLABS_API_KEY`
- Make sure there are no extra spaces or quotes around the values

### Keys not working
- Verify keys are correct (copy-paste can introduce errors)
- Check if keys have expired or been revoked
- Ensure you have sufficient credits/quota

## For Team Members

When cloning the repository:
1. Copy `env.example` to `.env`
2. Fill in your own API keys (or get them from the team lead)
3. Never commit your `.env` file

## Production Deployment

For production builds, consider:
- Using secure key management services (AWS Secrets Manager, Google Secret Manager, etc.)
- Using CI/CD environment variables
- Using platform-specific secure storage (Keychain on iOS, Keystore on Android)
