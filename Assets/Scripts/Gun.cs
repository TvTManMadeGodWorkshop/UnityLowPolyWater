using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Gun : MonoBehaviour
{
    public float CD;
    
    public GameObject bullet;
    public float muzzleVel;

    float timer;

    // Start is called before the first frame update
    void Start()
    {
        timer = Random.Range(0.0f, 1.5f);
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void FixedUpdate()
    {
        if(Time.time - timer > CD)
        {
            GameObject obj = Instantiate(bullet, transform.position, transform.rotation);

            Vector3 rot = new Vector3(Random.Range(-5.0f, 5.0f), Random.Range(-5.0f, 5.0f), Random.Range(-5.0f, 5.0f));


            obj.GetComponent<Bullet>().velocity = Quaternion.Euler(rot) * obj.transform.forward * muzzleVel;

            timer = Time.time;
        }
    }

    public Color col = Color.white;

    private void OnDrawGizmos()
    {
        Gizmos.color = col;
        Vector3 pos = transform.position;
        Vector3 vel = transform.forward * muzzleVel;
        for (int i = 0; i < 10; i++)
        {
            Gizmos.DrawLine(pos, pos + vel);
            pos += vel;
            vel += bullet.GetComponent<Bullet>().g * Vector3.down;
            
        }
    }
}
