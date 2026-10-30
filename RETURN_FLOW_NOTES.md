# Return Recording Flow

This update adds two home screen actions:

- Record Packing
- Record Return

## Packing
- Scan the order/tracking value.
- Record the packing video.
- The app saves the video locally and uploads it to Google Drive inside:
  - `PackProof / YYYY-MM-DD / <tracking-or-order-id> /`

## Return
- Scan the return tracking ID.
- The app looks inside Google Drive under `PackProof` for an existing folder with the same tracking/order ID.
- If found, the return video is uploaded into that same Google Drive folder.
- Locally, the app also tries to save the return video into the same local folder used for the earlier recording.

## Important
- For return recording to work, the original packing folder must already exist in Google Drive.
- If no matching folder is found, the app shows an error instead of uploading the return video to the wrong place.
