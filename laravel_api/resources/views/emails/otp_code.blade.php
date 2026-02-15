<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>PalmRead Code</title>
  </head>
  <body style="font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; line-height: 1.4; color: #0f172a;">
    <p style="margin: 0 0 12px 0;">Your PalmRead verification code is:</p>
    <p style="margin: 0 0 16px 0; font-size: 28px; font-weight: 800; letter-spacing: 4px;">
      {{ $code }}
    </p>
    <p style="margin: 0 0 12px 0; color: #475569;">
      This code expires in {{ $expiresInMinutes }} minute{{ $expiresInMinutes === 1 ? '' : 's' }}.
    </p>
    <p style="margin: 0; color: #94a3b8; font-size: 12px;">
      If you did not request this code, you can ignore this email.
    </p>
  </body>
</html>

