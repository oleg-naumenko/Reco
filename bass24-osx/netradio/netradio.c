/*
	BASS internet radio example
	Copyright (c) 2002-2015 Un4seen Developments Ltd.
*/

#include <Carbon/Carbon.h>
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>
#include "bass.h"

#define Sleep(x) usleep((x)*1000)

WindowPtr win;
pthread_mutex_t lock=PTHREAD_MUTEX_INITIALIZER;
DWORD req=0;	// request number/counter
HSTREAM chan;	// stream handle
EventLoopTimerRef prebuftimer;

const char *urls[10]={ // preset stream URLs
	"http://www.radioparadise.com/m3u/mp3-128.m3u", "http://www.radioparadise.com/m3u/mp3-32.m3u",
	"http://icecast.timlradio.co.uk/vr160.ogg", "http://icecast.timlradio.co.uk/vr32.ogg",
	"http://icecast.timlradio.co.uk/a8160.ogg", "http://icecast.timlradio.co.uk/a832.ogg",
	"http://somafm.com/secretagent.pls", "http://somafm.com/secretagent24.pls",
	"http://somafm.com/suburbsofgoa.pls", "http://somafm.com/suburbsofgoa24.pls"
};

// display error messages
void Error(const char *es)
{
	short i;
	char mes[200];
	sprintf(mes,"%s\n(error code: %d)",es,BASS_ErrorGetCode());
	CFStringRef ces=CFStringCreateWithCString(0,mes,0);
	DialogRef alert;
	CreateStandardAlert(0,CFSTR("Error"),ces,NULL,&alert);
	RunStandardAlert(alert,NULL,&i);
	CFRelease(ces);
}

ControlRef GetControl(int id)
{
	ControlRef cref;
	ControlID cid={0,id};
	GetControlByID(win,&cid,&cref);
	return cref;
}

void SetupControlHandler(int id, DWORD event, EventHandlerProcPtr proc)
{
	EventTypeSpec etype={kEventClassControl,event};
	ControlRef cref=GetControl(id);
	InstallControlEventHandler(cref,NewEventHandlerUPP(proc),1,&etype,cref,NULL);
}

void SetStaticText(int id, const char *text)
{
	ControlRef cref=GetControl(id);
	SetControlData(cref,kControlNoPart,kControlStaticTextTextTag,strlen(text),text);
	DrawOneControl(cref);
}

void PostCustomEvent(DWORD id, void *data, DWORD size)
{
	EventRef e;
	CreateEvent(NULL,'blah','blah',0,0,&e);
	SetEventParameter(e,'evid',0,sizeof(id),&id);
	SetEventParameter(e,'data',0,size,data);
	PostEventToQueue(GetMainEventQueue(),e,kEventPriorityHigh);
	ReleaseEvent(e);
}

// update stream title from metadata
void DoMeta()
{
	const char *meta=BASS_ChannelGetTags(chan,BASS_TAG_META);
	if (meta) { // got Shoutcast metadata
		char *p=strstr(meta,"StreamTitle='");
		if (p) {
			p=strdup(p+13);
			strchr(p,';')[-1]=0;
			SetStaticText(30,p);
			free(p);
		}
	} else {
		meta=BASS_ChannelGetTags(chan,BASS_TAG_OGG);
		if (meta) { // got Icecast/OGG tags
			const char *artist=NULL,*title=NULL,*p=meta;
			for (;*p;p+=strlen(p)+1) {
				if (!strncasecmp(p,"artist=",7)) // found the artist
					artist=p+7;
				if (!strncasecmp(p,"title=",6)) // found the title
					title=p+6;
			}
			if (title) {
				if (artist) {
					char text[100];
					snprintf(text,sizeof(text),"%s - %s",artist,title);
					SetStaticText(30,text);
				} else
					SetStaticText(30,title);
			}
		}
    }
}

void CALLBACK MetaSync(HSYNC handle, DWORD channel, DWORD data, void *user)
{
	// Carbon UI stuff is not thread-safe, so just posting an event to the main thread here
	PostCustomEvent('meta',0,0);
}

void CALLBACK EndSync(HSYNC handle, DWORD channel, DWORD data, void *user)
{
	PostCustomEvent('end ',0,0);
}

void CALLBACK StatusProc(const void *buffer, DWORD length, void *user)
{
	if (buffer && !length && (DWORD)user==req) { // got HTTP/ICY tags, and this is still the current request
		char *status=strdup(buffer);
		PostCustomEvent('stat',&status,sizeof(status));
	}
}

pascal void PrebufTimerProc(EventLoopTimerRef inTimer, void *inUserData)
{ // monitor prebuffering progress
	DWORD progress=BASS_StreamGetFilePosition(chan,BASS_FILEPOS_BUFFER)
		*100/BASS_StreamGetFilePosition(chan,BASS_FILEPOS_END); // percentage of buffer filled
	if (progress>75 || !BASS_StreamGetFilePosition(chan,BASS_FILEPOS_CONNECTED)) { // over 75% full (or end of download)
		RemoveEventLoopTimer(prebuftimer); // finished prebuffering, stop monitoring
		SetStaticText(31,"playing");
		{ // get the broadcast name and URL
			const char *icy=BASS_ChannelGetTags(chan,BASS_TAG_ICY);
			if (!icy) icy=BASS_ChannelGetTags(chan,BASS_TAG_HTTP); // no ICY tags, try HTTP
			if (icy) {
				for (;*icy;icy+=strlen(icy)+1) {
					if (!strncasecmp(icy,"icy-name:",9))
						SetStaticText(31,icy+9);
					if (!strncasecmp(icy,"icy-url:",8))
						SetStaticText(32,icy+8);
				}
			}
		}
		// get the stream title and set sync for subsequent titles
		DoMeta();
		BASS_ChannelSetSync(chan,BASS_SYNC_META,0,&MetaSync,0); // Shoutcast
		BASS_ChannelSetSync(chan,BASS_SYNC_OGG_CHANGE,0,&MetaSync,0); // Icecast/OGG
		// set sync for end of stream
		BASS_ChannelSetSync(chan,BASS_SYNC_END,0,&EndSync,0);
		// play it!
		BASS_ChannelPlay(chan,FALSE);
	} else {
		char text[20];
		sprintf(text,"buffering... %d%%",progress);
		SetStaticText(31,text);
	}
}

void *OpenURL(void *url)
{
	DWORD c,r;
	pthread_mutex_lock(&lock); // make sure only 1 thread at a time can do the following
	r=++req; // increment the request counter for this request
	pthread_mutex_unlock(&lock);
	RemoveEventLoopTimer(prebuftimer); // stop prebuffer monitoring
	BASS_StreamFree(chan); // close old stream
	PostCustomEvent('open',0,0);
	c=BASS_StreamCreateURL(url,0,BASS_STREAM_BLOCK|BASS_STREAM_STATUS|BASS_STREAM_AUTOFREE,StatusProc,(void*)r);
	free(url); // free temp URL buffer
	pthread_mutex_lock(&lock);
	if (r!=req) { // there is a newer request, discard this stream
		pthread_mutex_unlock(&lock);
		if (c) BASS_StreamFree(c);
		return NULL;
	}
	chan=c; // this is now the current stream
	pthread_mutex_unlock(&lock);
	if (!chan) {
		PostCustomEvent('end ',0,0);
//		Error("Can't play the stream");
	} else
		InstallEventLoopTimer(GetMainEventLoop(),kEventDurationNoWait,kEventDurationSecond/20,NewEventLoopTimerUPP(PrebufTimerProc),0,&prebuftimer); // start prebuffer monitoring
	return NULL;
}

pascal OSStatus RadioEventHandler(EventHandlerCallRef inHandlerRef, EventRef inEvent, void *inUserData)
{
	ControlID cid;
	GetControlID(inUserData,&cid);
	Size s;
	char *url;
	if (cid.id==51) { // play a custom URL
		char buf[100];
		GetControlData(GetControl(50),0,kControlEditTextTextTag,sizeof(buf)-1,buf,&s); // get the URL
		buf[s]=0;
		url=strdup(buf);
	} else { // play a preset
		url=strdup(urls[cid.id-10]);
	}
	if (GetControl32BitValue(GetControl(41)))
		BASS_SetConfigPtr(BASS_CONFIG_NET_PROXY,NULL); // disable proxy
	else {
		char proxy[100];
		GetControlData(GetControl(40),0,kControlEditTextTextTag,sizeof(proxy)-1,proxy,&s);
		proxy[sizeof(proxy)-1]=0;
		BASS_SetConfigPtr(BASS_CONFIG_NET_PROXY,proxy); // set proxy server
	}
	// open URL in a new thread (so that main thread is free)
	pthread_t tid;
	pthread_create(&tid,NULL,OpenURL,url);
	pthread_detach(tid);
	return noErr;
}

pascal OSStatus CustomEventHandler(EventHandlerCallRef inHandlerRef, EventRef inEvent, void *inUserData)
{
	DWORD id=0;
	GetEventParameter(inEvent,'evid',0,NULL,sizeof(id),NULL,&id);
	switch (id) {
		case 'open':
			SetStaticText(31,"connecting...");
			SetStaticText(30,"");
			SetStaticText(32,"");
			break;
		case 'end ':
			SetStaticText(31,"not playing");
			SetStaticText(30,"");
			SetStaticText(32,"");
			break;
		case 'stat':
			{
				char *status;
				GetEventParameter(inEvent,'data',0,NULL,sizeof(status),NULL,&status);
				SetStaticText(32,status); // display connection status
				free(status);
			}
			break;
		case 'meta':
			DoMeta();
			break;
	}
	return noErr;
}

int main(int argc, char* argv[])
{
	IBNibRef 		nibRef;
	OSStatus		err;

	// check the correct BASS was loaded
	if (HIWORD(BASS_GetVersion())!=BASSVERSION) {
		Error("An incorrect version of BASS was loaded");
		return 0;
	}

	// initialize default output device
	if (!BASS_Init(-1,44100,0,NULL,NULL)) {
		Error("Can't initialize device");
		return 0;
	}

	BASS_SetConfig(BASS_CONFIG_NET_PLAYLIST,1); // enable playlist processing
	BASS_SetConfig(BASS_CONFIG_NET_PREBUF,0); // minimize automatic pre-buffering, so we can do it (and display it) instead

	// Create Window and stuff
	err = CreateNibReference(CFSTR("netradio"), &nibRef);
	if (err) return err;
	err = CreateWindowFromNib(nibRef, CFSTR("Window"), &win);
	if (err) return err;
	DisposeNibReference(nibRef);

	int a;
	for (a=10;a<20;a++)
		SetupControlHandler(a,kEventControlHit,RadioEventHandler);
	SetupControlHandler(51,kEventControlHit,RadioEventHandler);
	{
		EventTypeSpec etype={'blah','blah'};
		InstallApplicationEventHandler(NewEventHandlerUPP(CustomEventHandler),1,&etype,NULL,NULL);
	}

	ShowWindow(win);
	RunApplicationEventLoop();

	BASS_Free();

    return 0; 
}
