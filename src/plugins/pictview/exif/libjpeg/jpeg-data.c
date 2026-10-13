/* jpeg-data.c
 *
 * Copyright © 2001 Lutz Müller <lutz@users.sourceforge.net>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include "config.h"
#include "jpeg-data.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <crtdbg.h>

#include <libexif/i18n.h>

#pragma warning(push)
#pragma warning(disable: 4267) // FIXME_X64 - warning temporarily suppressed, fix it

struct _JPEGDataPrivate
{
	unsigned int ref_count;

	ExifLog *log;

	/* Tandem Commander 132: the loader stopped before the end of the data (it does not
	   understand the file) - such data must never be saved: the result would be the
	   parsed beginning of the file only */
	int incomplete;
};

JPEGData *
jpeg_data_new (void)
{
	JPEGData *data;

	data = malloc (sizeof (JPEGData));
	if (!data)
		return (NULL);
	memset (data, 0, sizeof (JPEGData));
	data->priv = malloc (sizeof (JPEGDataPrivate));
	if (!data->priv) {
		free (data);
		return (NULL);
	}
	memset (data->priv, 0, sizeof (JPEGDataPrivate));
	data->priv->ref_count = 1;

	return (data);
}

void
jpeg_data_append_section (JPEGData *data)
{
	JPEGSection *s;

	if (!data) return;

	if (!data->count)
		s = malloc (sizeof (JPEGSection));
	else
		s = realloc (data->sections,
			     sizeof (JPEGSection) * (data->count + 1));
	if (!s) {
		EXIF_LOG_NO_MEMORY (data->priv->log, "jpeg-data", 
				sizeof (JPEGSection) * (data->count + 1));
		return;
	}
	memset(s + data->count, 0, sizeof (JPEGSection));
	data->sections = s;
	data->count++;
}

/* jpeg_data_save_file returns 1 on succes, 0 on failure */
int
jpeg_data_save_file (JPEGData *data, const char *path)
{
	FILE *f;
	unsigned char *d = NULL;
	unsigned int size = 0, written;

	jpeg_data_save_data (data, &d, &size);
	if (!d)
		return 0;

	remove (path);
	f = fopen (path, "wb");
	if (!f) {
		free (d);
		return 0;
	}
	written = fwrite (d, 1, size, f);
	fclose (f);
	free (d);
	if (written == size)  {
		return 1;
	}
	remove(path);
	return 0;
}

/* Tandem Commander 132: grows the output buffer; 0 = low memory */
static int
jpeg_data_grow (unsigned char **d, unsigned int size)
{
	unsigned char *n = realloc (*d, size ? size : 1);

	if (!n) return 0;
	*d = n;
	return 1;
}

/* Tandem Commander 132: on any failure *d is NULL and *ds is 0 (jpeg_data_save_file then
   returns 0). Failures: data the loader did not read whole, a section that does not fit
   the 16-bit length of a JPEG segment (the length used to wrap - a broken file), an Exif
   block that cannot be written (the marker used to be written without its length), low
   memory. */
void
jpeg_data_save_data (JPEGData *data, unsigned char **d, unsigned int *ds)
{
	unsigned int i, eds = 0;
	JPEGSection s;
	unsigned char *ed = NULL;

	if (!data)
		return;
	if (!d)
		return;
	if (!ds)
		return;

	*ds = 0;
	if (data->priv && data->priv->incomplete)
		goto fail;

	for (i = 0; i < data->count; i++) {
		s = data->sections[i];

		/* Write the marker */
		if (!jpeg_data_grow (d, *ds + 2)) goto fail;
		(*d)[*ds + 0] = 0xff;
		(*d)[*ds + 1] = s.marker;
		*ds += 2;

		switch (s.marker) {
		case JPEG_MARKER_SOI:
		case JPEG_MARKER_EOI:
			break;
		default:
			if (s.marker == JPEG_MARKER_APP1 && s.exif) {
				ed = NULL;
				eds = 0;
				exif_data_save_data (s.content.app1, &ed, &eds);
				if (!ed) goto fail;
				if (eds + 2 > 0xffff || !jpeg_data_grow (d, *ds + 2 + eds)) {
					free (ed);
					goto fail;
				}
				(*d)[*ds + 0] = (eds + 2) >> 8;
				(*d)[*ds + 1] = (eds + 2) >> 0;
				*ds += 2;
				memcpy (*d + *ds, ed, eds);
				*ds += eds;
				free (ed);
				break;
			}
			if (s.content.generic.size + 2 > 0xffff ||
			    (s.content.generic.size && !s.content.generic.data) ||
			    !jpeg_data_grow (d, *ds + s.content.generic.size + 2))
				goto fail;
			(*d)[*ds + 0] = (s.content.generic.size + 2) >> 8;
			(*d)[*ds + 1] = (s.content.generic.size + 2) >> 0;
			*ds += 2;
			if (s.content.generic.size)
				memcpy (*d + *ds, s.content.generic.data,
					s.content.generic.size);
			*ds += s.content.generic.size;

			/* In case of SOS, we need to write the data. */
			if (s.marker == JPEG_MARKER_SOS) {
				if (data->size && !data->data) goto fail;
				if (!jpeg_data_grow (d, *ds + data->size)) goto fail;
				if (data->size)
					memcpy (*d + *ds, data->data, data->size);
				*ds += data->size;
			}
			break;
		}
	}
	return;

fail:
	free (*d);
	*d = NULL;
	*ds = 0;
}

JPEGData *
jpeg_data_new_from_data (const unsigned char *d,
			 unsigned int size)
{
	JPEGData *data;

	data = jpeg_data_new ();
	jpeg_data_load_data (data, d, size);
	return (data);
}

void
jpeg_data_load_data (JPEGData *data, const unsigned char *d,
		     unsigned int size)
{
	unsigned int i, o, len, rest, before;
	JPEGSection *s;
	JPEGMarker marker;

	if (!data) return;
	if (!d) return;

	for (o = 0; o < size;) {

		/*
		 * JPEG sections start with 0xff. The first byte that is
		 * not 0xff is a marker (hopefully).
		 */
		for (i = 0; i < MIN(7, size - o); i++)
			if (d[o + i] != 0xff)
				break;
		/* Tandem Commander 132: every way out of this loop before the end of the
		   data marks the result as incomplete (see _JPEGDataPrivate); the read of
		   d[o + i] is inside the data now */
		if (o + i >= size || !JPEG_IS_MARKER (d[o + i])) {
			exif_log (data->priv->log, EXIF_LOG_CODE_CORRUPT_DATA, "jpeg-data",
					_("Data does not follow JPEG specification."));
			data->priv->incomplete = 1;
			return;
		}
		marker = d[o + i];

		/* Append this section (Tandem Commander 132: when that fails, the last
		   section must not be taken for the new one) */
		before = data->count;
		jpeg_data_append_section (data);
		if (data->count == before) {
			data->priv->incomplete = 1;
			return;
		}
		s = &data->sections[data->count - 1];
		s->marker = marker;
		s->exif = 0;
		o += i + 1;

		switch (s->marker) {
		case JPEG_MARKER_SOI:
		case JPEG_MARKER_EOI:
			break;
		default:

			/* Read the length of the section */
			if (o + 2 > size) { data->priv->incomplete = 1; o = size; break; }
			len = ((d[o] << 8) | d[o + 1]) - 2;
			if (len > size) { data->priv->incomplete = 1; o = size; break; }
			o += 2;
			if (o + len > size) { data->priv->incomplete = 1; o = size; break; }

			/* Tandem Commander 132: no APP1 block is parsed here - each is kept
			   byte for byte until jpeg_data_set_exif_data replaces the Exif one.
			   Every APP1 used to be parsed as Exif and serialised again: an XMP
			   block ("http://ns.adobe.com/xap/1.0/") came back as an empty Exif
			   block, and an Exif block that was not the one being updated came
			   back with its unknown tags dropped and default tags added. */
			{
				s->content.generic.size = len;
				s->content.generic.data =
						malloc (sizeof (char) * (len ? len : 1));
				if (!s->content.generic.data) {
					s->content.generic.size = 0;
					data->priv->incomplete = 1;
					return;
				}
				memcpy (s->content.generic.data, &d[o], len);

				/* In case of SOS, image data will follow. */
				if (s->marker == JPEG_MARKER_SOS && !data->data) {
					/* Tandem Commander 132: all the rest of the file is the
					   image data, without its last two bytes only when they
					   are JPEG_MARKER_EOI. (The test was "the byte before the
					   last one is 0xff": a file with data behind the picture
					   that ended so lost its last two bytes, and the length
					   wrapped when fewer than two bytes followed.) */
					rest = size - o - len;
					if (rest >= 2 && d[size - 2] == 0xff &&
					    d[size - 1] == JPEG_MARKER_EOI)
						rest -= 2;
					data->data = malloc (sizeof (char) * (rest ? rest : 1));
					if (!data->data) {
						data->priv->incomplete = 1;
						return;
					}
					data->size = rest;
					memcpy (data->data, d + o + len,
						data->size);
					o += data->size;
				}
			}
			o += len;
			break;
		}
	}
}

JPEGData *
jpeg_data_new_from_file (const char *path)
{
	JPEGData *data;

	data = jpeg_data_new ();
	jpeg_data_load_file (data, path);
	return (data);
}

void
jpeg_data_load_file (JPEGData *data, const char *path)
{
	FILE *f;
	unsigned char *d;
	unsigned int size;
	long fsize;

	if (!data) return;
	if (!path) return;

	f = fopen (path, "rb");
	if (!f) {
		data->priv->incomplete = 1;
		exif_log (data->priv->log, EXIF_LOG_CODE_CORRUPT_DATA, "jpeg-data",
				_("Path '%s' invalid."), path);
		return;
	}

	/* For now, we read the data into memory. Patches welcome...
	   Tandem Commander 132: a file that was not read is "incomplete" (nothing may be
	   saved from it); a size that does not fit the 32-bit offsets used here too */
	fseek (f, 0, SEEK_END);
	fsize = ftell (f);
	fseek (f, 0, SEEK_SET);
	if (fsize <= 0 || fsize >= 0x7fffffff) {
		data->priv->incomplete = 1;
		fclose (f);
		return;
	}
	size = (unsigned int) fsize;
	d = malloc (size);
	if (!d) {
		EXIF_LOG_NO_MEMORY (data->priv->log, "jpeg-data", size);
		data->priv->incomplete = 1;
		fclose (f);
		return;
	}
	if (fread (d, 1, size, f) != size) {
		data->priv->incomplete = 1;
		free (d);
		fclose (f);
		exif_log (data->priv->log, EXIF_LOG_CODE_CORRUPT_DATA, "jpeg-data",
				_("Could not read '%s'."), path);
		return;
	}
	fclose (f);

	jpeg_data_load_data (data, d, size);
	free (d);
}

void
jpeg_data_ref (JPEGData *data)
{
	if (!data)
		return;

	data->priv->ref_count++;
}

void
jpeg_data_unref (JPEGData *data)
{
	if (!data)
		return;

	if (data->priv) {
		data->priv->ref_count--;
		if (!data->priv->ref_count)
			jpeg_data_free (data);
	}
}

void
jpeg_data_free (JPEGData *data)
{
	unsigned int i;
	JPEGSection s;

	if (!data)
		return;

	if (data->count) {
		for (i = 0; i < data->count; i++) {
			s = data->sections[i];
			switch (s.marker) {
			case JPEG_MARKER_SOI:
			case JPEG_MARKER_EOI:
				break;
			case JPEG_MARKER_APP1:
				if (s.exif) {
					exif_data_unref (s.content.app1);
					break;
				}
				/* fall through: an APP1 that is not Exif is generic */
			default:
				free (s.content.generic.data);
				break;
			}
		}
		free (data->sections);
	}

	if (data->data)
		free (data->data);

	if (data->priv) {
		if (data->priv->log) {
			exif_log_unref (data->priv->log);
			data->priv->log = NULL;
		}
		free (data->priv);
	}

	free (data);
}

void
jpeg_data_dump (JPEGData *data)
{
	unsigned int i;
	JPEGContent content;
	JPEGMarker marker;

	if (!data)
		return;

	printf ("Dumping JPEG data (%i bytes of data)...\n", data->size);
	for (i = 0; i < data->count; i++) {
		marker = data->sections[i].marker;
		content = data->sections[i].content;
		printf ("Section %i (marker 0x%x - %s):\n", i, marker,
			jpeg_marker_get_name (marker));
		printf ("  Description: %s\n",
			jpeg_marker_get_description (marker));
		switch (marker) {
                case JPEG_MARKER_SOI:
                case JPEG_MARKER_EOI:
			break;
                case JPEG_MARKER_APP1:
			if (data->sections[i].exif) {
				exif_data_dump (content.app1);
				break;
			}
			/* fall through */
                default:
			printf ("  Size: %i\n", content.generic.size);
                        printf ("  Unknown content.\n");
                        break;
                }
        }
}

static JPEGSection *
jpeg_data_get_section (JPEGData *data, JPEGMarker marker)
{
	unsigned int i;

	if (!data)
		return (NULL);

	for (i = 0; i < data->count; i++)
		if (data->sections[i].marker == marker &&
		    (marker != JPEG_MARKER_APP1 || data->sections[i].exif))
			return (&data->sections[i]);
	return (NULL);
}

ExifData *
jpeg_data_get_exif_data (JPEGData *data)
{
	JPEGSection *section;

	if (!data)
		return NULL;

	section = jpeg_data_get_section (data, JPEG_MARKER_APP1);
	if (section) {
		exif_data_ref (section->content.app1);
		return (section->content.app1);
	}

	return (NULL);
}

/* Tandem Commander 132: is this section an Exif block still held as raw bytes? */
static int
jpeg_section_is_raw_exif (const JPEGSection *s)
{
	return s->marker == JPEG_MARKER_APP1 && !s->exif &&
	       s->content.generic.size >= 6 && s->content.generic.data &&
	       !memcmp (s->content.generic.data, "Exif\0\0", 6);
}

/* Tandem Commander 132: the bytes of the first Exif block of the file ("Exif\0\0" and
   what follows), as they are in the file; 0 when the file has none */
int
jpeg_data_get_exif_bytes (JPEGData *data, const unsigned char **d, unsigned int *size)
{
	unsigned int i;

	if (!data || !d || !size) return 0;
	for (i = 0; i < data->count; i++)
		if (jpeg_section_is_raw_exif (&data->sections[i])) {
			*d = data->sections[i].content.generic.data;
			*size = data->sections[i].content.generic.size;
			return 1;
		}
	return 0;
}

/* Tandem Commander 135: the bytes of the first Exif block (the one
   jpeg_data_get_exif_bytes gives) replaced by a copy of 'd'; returns 0 when the file has no
   such block or memory is low (the data are marked incomplete then - nothing is saved) */
int
jpeg_data_set_exif_bytes (JPEGData *data, const unsigned char *d, unsigned int size)
{
	unsigned int i;
	unsigned char *copy;

	if (!data || !d || size < 6) return 0;
	for (i = 0; i < data->count; i++)
		if (jpeg_section_is_raw_exif (&data->sections[i])) {
			copy = malloc (size);
			if (!copy) {
				data->priv->incomplete = 1;
				return 0;
			}
			memcpy (copy, d, size);
			free (data->sections[i].content.generic.data);
			data->sections[i].content.generic.data = copy;
			data->sections[i].content.generic.size = size;
			return 1;
		}
	return 0;
}

/* Tandem Commander 132: replaces the first Exif block of the file (the one
   jpeg_data_get_exif_bytes gives); every other block stays as it was read */
void
jpeg_data_set_exif_data (JPEGData *data, ExifData *exif_data)
{
	JPEGSection *section = NULL;
	unsigned int i, before;

	if (!data) return;

	for (i = 0; i < data->count && !section; i++)
		if (jpeg_section_is_raw_exif (&data->sections[i]) ||
		    (data->sections[i].marker == JPEG_MARKER_APP1 && data->sections[i].exif))
			section = &data->sections[i];
	if (!section) {
		before = data->count;
		jpeg_data_append_section (data);
		if (data->count == before || data->count < 2) {
			data->priv->incomplete = 1;
			return;
		}
		memmove (&data->sections[2], &data->sections[1],
			 sizeof (JPEGSection) * (data->count - 2));
		section = &data->sections[1];
	} else if (section->exif) {
		exif_data_unref (section->content.app1);
	} else {
		free (section->content.generic.data);
	}
	section->marker = JPEG_MARKER_APP1;
	section->exif = 1;
	section->content.app1 = exif_data;
	exif_data_ref (exif_data);
}

void
jpeg_data_log (JPEGData *data, ExifLog *log)
{
	if (!data || !data->priv) return;
	if (data->priv->log) exif_log_unref (data->priv->log);
	data->priv->log = log;
	exif_log_ref (log);
}

#pragma warning(pop) // FIXME_X64 - warning temporarily suppressed, fix it
