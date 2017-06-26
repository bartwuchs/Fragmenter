using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Fragmenter : MonoBehaviour
{
    #region public parameters
    public Transform Target;
    public AudioClip Clip_Suck;
    public AudioClip Clip_Apear;

   
    #endregion


    #region private parameters

    private List<Material> _orgMaterial;
    private List<Material> _fragmentedMaterial;

    private Dictionary<Renderer, Material> rendMatOrg;
    private Dictionary<Renderer, Material> rendMatFrag;
    private Renderer[] _renderers;

    private bool _readyToCatch;
    private float _timePassed;
    private float _maxTime = 10;
    private float _rotation;
    
    private AudioSource _audioSource;

    #endregion


    #region Initialization
    void Start ()
	{
	    GetComponent<Rigidbody>().isKinematic = true;
	    
	    _audioSource = GetComponent<AudioSource>();

	    InitMaterial();

        StartCoroutine(Show());


	}

    private void InitMaterial()
    {
        _renderers = GetComponentsInChildren<Renderer>();
        rendMatOrg = new Dictionary<Renderer, Material>();
        rendMatFrag = new Dictionary<Renderer, Material>();
        foreach (var renderer in _renderers)
        {
            rendMatOrg.Add(renderer, renderer.material);
            rendMatFrag.Add(renderer, GetFragMaterial(renderer.material));
        }
    }
  
    private Material GetFragMaterial(Material orgMaterial)
    {
        var fragmentedMaterial = new Material(Shader.Find("Custom/Fragment4"));
        fragmentedMaterial.mainTexture = orgMaterial.mainTexture;
        fragmentedMaterial.SetTexture("_DispTex", FragmentationManager.Instance.NoiseTexture);
        fragmentedMaterial.SetFloat("_Randomness", FragmentationManager.Instance.Randomness);
        fragmentedMaterial.SetFloat("_Displacement", FragmentationManager.Instance.StartDisplacement);
        fragmentedMaterial.SetColor("_SpecColor", FragmentationManager.Instance.SpecularColor);
        fragmentedMaterial.SetFloat("_TurnSpeed", FragmentationManager.Instance.TurnSpeed);
        fragmentedMaterial.SetFloat("_Gloss", FragmentationManager.Instance.Gloss);
        return fragmentedMaterial;
    }

    private void SetContraints()
    {
        GetComponent<Rigidbody>().constraints = RigidbodyConstraints.FreezeAll;
    }

    #endregion


    #region Render fragemtation shader
    // Update is called once per frame
    void Update () {
	    if (_readyToCatch)
	    {
	        SetAlert();
	    }
	}

    private IEnumerator Show()
    {
        yield return StartCoroutine(Apear());
        yield return new WaitForSeconds(FragmentationManager.Instance.RestTime);
        yield return StartCoroutine(MoveToWand());
    }

    //Show the Object, make it apear and contract to rest position
    public IEnumerator Apear()
    {
        SetContraints();
        SetFullyFragmented();
        yield return StartCoroutine(MoveToRest());

    }

 
    // rotate the fragments while in rest position
    private void SetAlert()
    {
        _timePassed += Time.deltaTime;
        float alert = Mathf.Clamp01(_timePassed/_maxTime);
        _rotation += alert*Time.deltaTime;
        foreach (var renderer in _renderers)
        {
         rendMatFrag[renderer].SetFloat("_TurnSpeedMultiplier", _rotation);
        }
    }

    //contract the object and reset original material when finished
    private IEnumerator MoveToRest()
    {
      
        //Play Audio
        _audioSource.clip = Clip_Apear;
        _audioSource.Play();

        float t = 0;
        float disp = FragmentationManager.Instance.StartDisplacement;
        while (t < FragmentationManager.Instance.MoveToRestTime)
        {
            t += Time.deltaTime;

            // calculate displacement
            disp = Mathf.Lerp(FragmentationManager.Instance.StartDisplacement,
                FragmentationManager.Instance.RestDisplacement, t / FragmentationManager.Instance.MoveToRestTime);

            //Set in renderers
            foreach (var renderer in _renderers)
            {
                rendMatFrag[renderer].SetFloat("_Displacement", disp);
            }
          
            yield return null;
        }
        _readyToCatch = true;
       
    }


    //Set fragments to maximum displacement
    void SetFullyFragmented()
    {
        foreach (var renderer in _renderers)
        {
            renderer.material = rendMatFrag[renderer];
            rendMatFrag[renderer].SetFloat("_Displacement", FragmentationManager.Instance.StartDisplacement);
        }
      
    }

    //reset the origina material
    void SetOriginalMaterial()
    {
        foreach (var renderer in _renderers)
        {
            renderer.material = rendMatOrg[renderer];
          
        }
    }

    //Move fragments to original mesh position and the whole game object to a target position
    private IEnumerator MoveToWand()
    {
        yield return new WaitForEndOfFrame();

      
        //Play Audio
        _audioSource.clip = Clip_Suck;
        _audioSource.Play();


        float t = 0;
        float disp = FragmentationManager.Instance.RestDisplacement;
        Vector3 startPosition = transform.position;
        
        while (t < FragmentationManager.Instance.MoveToWandTime)
        {
            t += Time.deltaTime;

            //Set Fragmentation
            disp = Mathf.Lerp(FragmentationManager.Instance.RestDisplacement,
                0, t / FragmentationManager.Instance.MoveToWandTime);
            foreach (var renderer in _renderers)
            {
                rendMatFrag[renderer].SetFloat("_Displacement", disp);
            }

            //Move
            transform.position = Vector3.Lerp(startPosition, Target.position /*+ _offsetTarget*/,
            t / FragmentationManager.Instance.MoveToWandTime);
           
          

            yield return null;
        }
      
      
        SetOriginalMaterial();
       
        enabled = false;
      
    }

    #endregion
}
