package software.solid.fluttervlcplayer;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.SurfaceTexture;
import android.net.Uri;
import android.util.Base64;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import androidx.annotation.NonNull;
import io.flutter.plugin.common.*;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.view.TextureRegistry;
import org.videolan.libvlc.IVLCVout;
import org.videolan.libvlc.LibVLC;
import org.videolan.libvlc.Media;
import org.videolan.libvlc.MediaPlayer;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import android.util.Log;

class FlutterVideoView implements PlatformView, MethodChannel.MethodCallHandler, MediaPlayer.EventListener {

    // Silences player log output.
    private static final boolean DISABLE_LOG_OUTPUT = true;

    final PluginRegistry.Registrar registrar;
    private final MethodChannel methodChannel;

    private QueuingEventSink eventSink;
    private final EventChannel eventChannel;

    private final Context context;

    private LibVLC libVLC;
    private MediaPlayer mediaPlayer;
    private TextureView textureView;
    private IVLCVout vout;
    private boolean playerDisposed;
    private boolean playerPlaying = false;
    private static final String TAG = "FlutterVideoView";

    public FlutterVideoView(Context context, PluginRegistry.Registrar _registrar, BinaryMessenger messenger, int id) {
        this.playerDisposed = false;

        this.context = context;
        this.registrar = _registrar;

        eventSink = new QueuingEventSink();
        eventChannel = new EventChannel(messenger, "flutter_video_plugin/getVideoEvents_" + id);

        eventChannel.setStreamHandler(
            new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object o, EventChannel.EventSink sink) {
                    eventSink.setDelegate(sink);
                }

                @Override
                public void onCancel(Object o) {
                    eventSink.setDelegate(null);
                }
            }
        );

        TextureRegistry.SurfaceTextureEntry textureEntry = registrar.textures().createSurfaceTexture();
        textureView = new TextureView(context);
        textureView.setSurfaceTexture(textureEntry.surfaceTexture());
        textureView.setSurfaceTextureListener(new TextureView.SurfaceTextureListener(){

            boolean wasPaused = false;

            @Override
            public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) {
                vout.setVideoSurface(new Surface(textureView.getSurfaceTexture()), null);
                vout.attachViews();
                textureView.forceLayout();
                if(wasPaused){
                    playerPlaying = true;
                    wasPaused = false;
                    mediaPlayer.play();
                    Log.e(TAG, "Media player on surface text available " + String.valueOf(playerPlaying));
                }
            }

            @Override
            public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {

            }

            @Override
            public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
                if(playerDisposed){
                    if(mediaPlayer != null) {
                        mediaPlayer.stop();
                        mediaPlayer.release();
                        mediaPlayer = null;
                    }
                    return true;
                }else{
                    mediaPlayer.pause();
                    wasPaused = true;
                    vout.detachViews();
                    return true;
                }
            }

            @Override
            public void onSurfaceTextureUpdated(SurfaceTexture surface) {

            }

        });

        methodChannel = new MethodChannel(messenger, "flutter_video_plugin/getVideoView_" + id);
        methodChannel.setMethodCallHandler(this);
    }

    @Override
    public View getView() {
        return textureView;
    }

    @Override
    public void dispose() {
        playerPlaying = false;
        playerDisposed = true;
        if(mediaPlayer != null) mediaPlayer.stop();
        vout.detachViews();
    }


    // Suppress WrongThread warnings from IntelliJ / Android Studio, because it looks like the advice
    // is wrong and actually breaks the library.
    @SuppressLint("WrongThread")
    @Override
    public void onMethodCall(MethodCall methodCall, @NonNull MethodChannel.Result result) {
        switch (methodCall.method) {
            case "initialize":
                if (textureView == null) {
                    textureView = new TextureView(context);
                }

                ArrayList<String> options = new ArrayList<>();
                options.add("--no-drop-late-frames");
                options.add("--no-skip-frames");
                options.add("--rtsp-tcp");

                if(DISABLE_LOG_OUTPUT) {
                    // Silence player log output.
                    options.add("--quiet");
                }

                libVLC = new LibVLC(context, options);
                mediaPlayer = new MediaPlayer(libVLC);
                //mediaPlayer.setVideoTrackEnabled(true);
                mediaPlayer.setEventListener(this);
                vout = mediaPlayer.getVLCVout();
                textureView.forceLayout();
                textureView.setFitsSystemWindows(true);
                vout.setVideoSurface(new Surface(textureView.getSurfaceTexture()), null);
                vout.attachViews();

                String initStreamURL = methodCall.argument("url");
                Media media = new Media(libVLC, Uri.parse(Uri.decode(initStreamURL)));
                mediaPlayer.setMedia(media);

                result.success(null);
                break;
            case "dispose":
                this.dispose();
                break;
            case "changeURL":
                if(libVLC == null) result.error("VLC_NOT_INITIALIZED", "The player has not yet been initialized.", false);

                mediaPlayer.stop();
                String newURL = methodCall.argument("url");
                Media newMedia = new Media(libVLC, Uri.parse(Uri.decode(newURL)));
                mediaPlayer.setMedia(newMedia);

                result.success(null);
                break;
            case "getSnapshot":
                String imageBytes;
                Map<String, String> response = new HashMap<>();
                Log.e("MediaPlayer", "Media player is playing : " + String.valueOf(playerPlaying));
                if (playerPlaying) {
                    Bitmap bitmap = textureView.getBitmap();
                    ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 100, outputStream);
                    imageBytes = Base64.encodeToString(outputStream.toByteArray(), Base64.DEFAULT);
                    if(imageBytes != null) Log.e("ImageBytes", "\n Image bytes is not null return the value. \n");
                    response.put("snapshot", imageBytes);
                }
                result.success(response);
                break;
            case "setPlaybackState":

                String playbackState = methodCall.argument("playbackState");
                if(playbackState == null) result.success(null);

                switch(playbackState){
                    case "play":
                        textureView.forceLayout();
                        playerPlaying = true;
                        mediaPlayer.play();
                        Log.e(TAG, "\n Player playing : " + String.valueOf(playerPlaying) + "\n");
                        break;
                    case "pause":
                        mediaPlayer.pause();
                        break;
                    case "stop":
                        mediaPlayer.stop();
                        playerPlaying = false;
                        Log.e(TAG, "\n Player playing : " + String.valueOf(playerPlaying) + "\n");
                        break;
                }

                result.success(null);
                break;

            case "setPlaybackSpeed":

                float playbackSpeed = Float.parseFloat((String) methodCall.argument("speed"));
                mediaPlayer.setRate(playbackSpeed);

                result.success(null);
                break;

            case "setTime":

                long time = Long.parseLong((String) methodCall.argument("time"));
                mediaPlayer.setTime(time);

                result.success(null);
                break;  
            case "soundController":
                double volume = methodCall.argument("volume");
                if(mediaPlayer != null) {
                    Log.e("SoundController", "Volume -> " + String.valueOf(volume));
                    volume = volume * 100;
                    mediaPlayer.setVolume((int)volume);
                } else return;
                result.success(null);
                break;
            case "soundActive":
                int active = methodCall.argument("active");
                if(mediaPlayer != null) {
                    Log.e("SoundActive", "Media Player sound active : " + String.valueOf(active));
                    if(active == 1) mediaPlayer.setVolume(100);
                    else if(active == 0) mediaPlayer.setVolume(0);
                    result.success(null);
                } else return;
                break;
            case "muteSound":
                if(mediaPlayer != null) {
                    Log.e("MuteSound", "Mute sound");
                    mediaPlayer.setVolume(0);
                } else return;
                break;
        }
    }

    @Override
    public void onEvent(MediaPlayer.Event event) {
        HashMap<String, Object> eventObject = new HashMap<>();

        switch (event.type) {
            case MediaPlayer.Event.Playing:
                // Insert buffering=false event first:
                eventObject.put("name", "buffering");
                eventObject.put("value", false);
                eventSink.success(eventObject.clone());
                eventObject.clear();

                // Now send playing info:
                int height = 0;
                int width = 0;

                Media.VideoTrack currentVideoTrack = (Media.VideoTrack) mediaPlayer.getMedia().getTrack(
                    mediaPlayer.getVideoTrack()
                );
                if (currentVideoTrack != null) {
                    height = currentVideoTrack.height;
                    width = currentVideoTrack.width;
                }

                eventObject.put("name", "playing");
                eventObject.put("value", true);
                eventObject.put("ratio", height > 0 ? (double) width / (double) height : 0D);
                eventObject.put("height", height);
                eventObject.put("width", width);
                eventObject.put("length", mediaPlayer.getLength());
                eventSink.success(eventObject.clone());
                break;

            case MediaPlayer.Event.EndReached:
                mediaPlayer.stop();
                eventObject.put("name", "ended");
                eventSink.success(eventObject);

                eventObject.clear();
                eventObject.put("name", "playing");
                eventObject.put("value", false);
                eventObject.put("reason", "EndReached");
                eventSink.success(eventObject);

            /*case MediaPlayer.Event.Opening:


                eventObject.put("name", "buffering");
                eventObject.put("value", true);
                eventSink.success(eventObject);

                eventObject.clear();
                eventObject.put("name", "playing");
                eventObject.put("value", false);
                eventObject.put("reason", "Buffering");
                eventSink.success(eventObject);
                break;*/

            case MediaPlayer.Event.Vout:
                vout.setWindowSize(textureView.getWidth(), textureView.getHeight());
                break;

            case MediaPlayer.Event.TimeChanged:
                eventObject.put("name", "timeChanged");
                eventObject.put("value", mediaPlayer.getTime());
                eventObject.put("speed", mediaPlayer.getRate());
                eventSink.success(eventObject);
                break;

            case MediaPlayer.Event.EncounteredError:
                System.err.println("(flutter_vlc_plugin) A VLC error occurred.");
            case MediaPlayer.Event.Paused:
            case MediaPlayer.Event.Stopped:
                eventObject.put("name", "buffering");
                eventObject.put("value", false);
                eventSink.success(eventObject);

                eventObject.clear();
                eventObject.put("name", "playing");
                eventObject.put("value", false);
                eventSink.success(eventObject);
                break;
        }
    }
}
