package com.flare.im.update

import android.app.Activity
import android.app.Application
import android.os.Bundle
import java.lang.ref.WeakReference

/**
 * The activity on screen, for an installer that hosts a store dialog. A view model outlives its
 * activities, so it reads [current] here instead of holding one.
 */
object FlareResumedActivity : Application.ActivityLifecycleCallbacks {
    private var tracking = false

    @Volatile
    private var resumed: WeakReference<Activity>? = null

    /** The activity on screen; null while none is. */
    val current: Activity? get() = resumed?.get()

    /** Starts following [application]. Call it before the first activity resumes; again does nothing. */
    @Synchronized
    fun track(application: Application) {
        if (tracking) return
        tracking = true
        application.registerActivityLifecycleCallbacks(this)
    }

    override fun onActivityResumed(activity: Activity) {
        resumed = WeakReference(activity)
    }

    override fun onActivityPaused(activity: Activity) {
        if (current === activity) resumed = null
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

    override fun onActivityStarted(activity: Activity) = Unit

    override fun onActivityStopped(activity: Activity) = Unit

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

    override fun onActivityDestroyed(activity: Activity) = Unit
}
