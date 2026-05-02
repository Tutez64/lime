#define MINIMP3_IMPLEMENTATION
#include <minimp3.h>
#include <minimp3_ex.h>
#include <media/containers/MP3.h>
#include <utils/Bytes.h>
#include <utils/ArrayBufferView.h>

namespace lime {

    bool MP3::Decode (Resource *resource, AudioBuffer *audioBuffer) {

        if (!resource || !audioBuffer) {
            return false;
        }

        const uint8_t *inputData = NULL;
        int inputLength = 0;
        Bytes fileBytes;

        if (resource->data) {

            inputData = resource->data->b;
            inputLength = resource->data->length;

        } else if (resource->path) {

            fileBytes.ReadFile (resource->path);

            if (!fileBytes.b || fileBytes.length == 0) {
                return false;
            }

            inputData = fileBytes.b;
            inputLength = fileBytes.length;

        } else {

            return false;

        }

        if (!inputData || inputLength <= 0) {
            return false;
        }

        mp3dec_t decoder;
        mp3dec_init (&decoder);

        mp3d_sample_t *pcmData = NULL;
        size_t decodedSamples = 0;
        int channels = 0;
        int sampleRate = 0;

        int result = mp3dec_load (&decoder, inputData, inputLength, &pcmData, &decodedSamples, &channels, &sampleRate);

        if (result != 0 || !pcmData || decodedSamples == 0 || channels <= 0 || sampleRate <= 0) {

            if (pcmData) {
                free (pcmData);
            }

            return false;

        }

        int byteLength = (int)(decodedSamples * sizeof (mp3d_sample_t));

        Bytes *decodedBytes = new Bytes ();
        decodedBytes->Resize (byteLength);
        memcpy (decodedBytes->b, pcmData, byteLength);

        if (audioBuffer->data) {
            delete audioBuffer->data;
        }

        audioBuffer->data = new ArrayBufferView (alloc_empty_object ());
        delete audioBuffer->data->buffer;
        audioBuffer->data->buffer = decodedBytes;
        audioBuffer->data->byteLength = byteLength;
        audioBuffer->data->length = byteLength;
        audioBuffer->data->bytesPerElement = 1;

        audioBuffer->sampleRate = sampleRate;
        audioBuffer->channels = channels;
        audioBuffer->bitsPerSample = 16;

        free (pcmData);

        return true;

    }

}
