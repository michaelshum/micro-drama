# Onda Web Site

Static marketing, support, and legal pages for the Onda iOS app.

## Deploy on Vercel

1. Create a new Vercel project from this repository.
2. Set the project root directory to `web`.
3. Leave the build command blank.
4. Leave the output directory blank.
5. Deploy.

Expected URLs after deployment:

- `/` for the marketing URL
- `/support` for the support URL
- `/privacy` for the privacy policy
- `/terms` for the terms of service

## Run locally

```bash
cd web
python3 -m http.server 8080
```

Open `http://localhost:8080`, `http://localhost:8080/support`, `http://localhost:8080/privacy`, or `http://localhost:8080/terms`.

Before App Store submission, confirm the contact email address in the support, privacy, and terms pages is correct for Onda.
